import '../../features/catalogo/data/models/catalogo.dart';
import '../../features/clima/data/models/clima.dart';
import '../clima/open_meteo_client.dart';
import 'paquete_reglas.dart';

/// Ids de eventos climáticos. Son los mismos que la tabla eventos_climaticos
/// del servidor (EventoClimaticoId.cs); si cambia el orden de los INSERT de los
/// catálogos hay que cambiarlo aquí también.
class EventoId {
  EventoId._();

  static const lluviaIntensa = 1;
  static const canicula = 2;
  static const vientoFuerte = 3;
  static const temperaturaExtrema = 4;
  static const riesgoHelada = 5;
  static const sinRiesgo = 6;
}

/// Umbrales que el productor puede ajustar (el resto son fijos, igual que en el servidor).
class UmbralesMotor {
  final int lluviaIntensaMm;
  final int vientoFuerteKmh;
  final int caniculaDias;

  const UmbralesMotor({
    this.lluviaIntensaMm = 100,
    this.vientoFuerteKmh = 40,
    this.caniculaDias = 7,
  });

  int get diasCanicula => caniculaDias < 1 ? 1 : caniculaDias;
}

class MotorLocalException implements Exception {
  final String mensaje;

  const MotorLocalException(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Motor de decisiones agroclimáticas. Es una función pura de
/// (clima, umbrales, reglas): no usa red, base de datos ni reloj propio.
/// Réplica del MotorDecisionesService del backend, con una mejora: la ventana de
/// canícula usa también los días ya pasados que trae Open-Meteo (past_days), así
/// que la canícula se detecta desde el primer día y no solo si la app guardó
/// el historial.
class MotorLocal {
  MotorLocal._();

  static const _umbralHeladaC = 2.0;
  static const _umbralCalorExtremoC = 35.0;

  /// Eventos activos en un día, en el orden de desempate del servidor.
  static List<int> eventosActivos({
    required double? temperaturaMin,
    required double? temperaturaMax,
    required double? precipitacion,
    required double? viento,
    required UmbralesMotor umbrales,
    required bool caniculaActiva,
  }) {
    final eventos = <int>[];

    if (temperaturaMin != null && temperaturaMin <= _umbralHeladaC) {
      eventos.add(EventoId.riesgoHelada);
    }
    if (precipitacion != null && precipitacion >= umbrales.lluviaIntensaMm) {
      eventos.add(EventoId.lluviaIntensa);
    }
    if (viento != null && viento >= umbrales.vientoFuerteKmh) {
      eventos.add(EventoId.vientoFuerte);
    }
    if (temperaturaMax != null && temperaturaMax >= _umbralCalorExtremoC) {
      eventos.add(EventoId.temperaturaExtrema);
    }
    if (caniculaActiva) {
      eventos.add(EventoId.canicula);
    }
    if (eventos.isEmpty) {
      eventos.add(EventoId.sinRiesgo);
    }
    return eventos;
  }

  static int prioridad(String nivel) => switch (nivel.toLowerCase()) {
    'alto' => 3,
    'medio' => 2,
    'bajo' => 1,
    _ => 0,
  };

  /// Canícula = [diasRequeridos] días seguidos, terminando en [indice], sin lluvia.
  /// Si la serie no tiene tantos días hacia atrás no se puede afirmar: false.
  static bool caniculaEn(List<DiaClima> dias, int indice, int diasRequeridos) {
    final inicio = indice - diasRequeridos + 1;
    if (inicio < 0) return false;
    for (var i = inicio; i <= indice; i++) {
      final lluvia = dias[i].precipitacion;
      if (lluvia != null && lluvia != 0) return false;
    }
    return true;
  }

  /// Etapa fenológica: la guardada en la parcela o, si no hay, la que
  /// corresponde por días desde la siembra.
  static int etapaId(
    PaqueteReglas paquete, {
    required int? etapaFenologicaId,
    required DateTime fechaSiembra,
    required DateTime hoy,
  }) {
    if (etapaFenologicaId != null) return etapaFenologicaId;
    if (paquete.etapas.isEmpty) {
      throw const MotorLocalException(
        'No hay etapas fenológicas configuradas en el catálogo.',
      );
    }

    final dias = DateTime.utc(hoy.year, hoy.month, hoy.day)
        .difference(
          DateTime.utc(fechaSiembra.year, fechaSiembra.month, fechaSiembra.day),
        )
        .inDays;

    // paquete.etapas viene ordenado por días ascendentes: gana la última que ya se cumplió.
    EtapaFenologica? elegida;
    for (final etapa in paquete.etapas) {
      final desde = etapa.diasDesdeSiembra;
      if (desde != null && desde <= dias) elegida = etapa;
    }
    return (elegida ?? paquete.etapas.first).id;
  }

  static ReglaLocal? _reglaPrioritaria(
    PaqueteReglas paquete,
    List<int> eventos, {
    required int cultivoId,
    required int etapaFenologicaId,
    required int tipoSueloId,
  }) {
    ReglaLocal? mejor;
    var maxPrioridad = -1;

    for (final evento in eventos) {
      final regla = paquete.buscar(
        eventoClimaticoId: evento,
        cultivoId: cultivoId,
        etapaFenologicaId: etapaFenologicaId,
        tipoSueloId: tipoSueloId,
      );
      if (regla == null) continue;

      final p = prioridad(regla.nivelRiesgo);
      if (p > maxPrioridad) {
        maxPrioridad = p;
        mejor = regla;
      }
    }
    return mejor;
  }

  /// Semáforo del día de [hoy].
  static Semaforo semaforoDeHoy({
    required PaqueteReglas paquete,
    required SerieClima serie,
    required DateTime hoy,
    required int cultivoId,
    required int? etapaFenologicaId,
    required int tipoSueloId,
    required DateTime fechaSiembra,
    required UmbralesMotor umbrales,
  }) {
    final indice = serie.indiceDe(hoy);
    if (indice == null) {
      throw const MotorLocalException(
        'No hay datos climáticos disponibles para hoy.',
      );
    }

    final dia = serie.dias[indice];
    final etapa = etapaId(
      paquete,
      etapaFenologicaId: etapaFenologicaId,
      fechaSiembra: fechaSiembra,
      hoy: hoy,
    );

    final eventos = eventosActivos(
      temperaturaMin: dia.temperaturaMin,
      temperaturaMax: dia.temperaturaMax,
      precipitacion: dia.precipitacion,
      viento: dia.vientoVelocidad,
      umbrales: umbrales,
      caniculaActiva: caniculaEn(serie.dias, indice, umbrales.diasCanicula),
    );

    final regla = _reglaPrioritaria(
      paquete,
      eventos,
      cultivoId: cultivoId,
      etapaFenologicaId: etapa,
      tipoSueloId: tipoSueloId,
    );

    if (regla == null) {
      throw const MotorLocalException(
        'No existe una regla agronómica para esta combinación de cultivo, etapa y suelo.',
      );
    }

    return Semaforo(
      nivelRiesgo: regla.nivelRiesgo,
      descripcionAlerta: regla.descripcionAlerta,
      acciones: regla.acciones,
      fecha: DateTime(hoy.year, hoy.month, hoy.day),
      eventoClimaticoId: regla.eventoClimaticoId,
    );
  }

  /// Resumen de los próximos [dias] días (empezando hoy).
  static ResumenSemanal resumenSemanal({
    required PaqueteReglas paquete,
    required SerieClima serie,
    required DateTime hoy,
    required int cultivoId,
    required int? etapaFenologicaId,
    required int tipoSueloId,
    required DateTime fechaSiembra,
    required UmbralesMotor umbrales,
    int dias = 7,
  }) {
    final inicio = serie.indiceDe(hoy);
    if (inicio == null) {
      throw const MotorLocalException('No hay pronóstico disponible para hoy.');
    }

    final etapa = etapaId(
      paquete,
      etapaFenologicaId: etapaFenologicaId,
      fechaSiembra: fechaSiembra,
      hoy: hoy,
    );

    final fin = inicio + dias < serie.dias.length
        ? inicio + dias
        : serie.dias.length;

    final resumenDias = <DiaResumenSemanal>[];
    ReglaLocal? reglaPeorDia;
    DateTime? diaMasCritico;
    var prioridadMaxima = -1;

    for (var i = inicio; i < fin; i++) {
      final dia = serie.dias[i];

      final eventos = eventosActivos(
        temperaturaMin: dia.temperaturaMin,
        temperaturaMax: dia.temperaturaMax,
        precipitacion: dia.precipitacion,
        viento: dia.vientoVelocidad,
        umbrales: umbrales,
        caniculaActiva: caniculaEn(serie.dias, i, umbrales.diasCanicula),
      );

      final reglaDelDia = _reglaPrioritaria(
        paquete,
        eventos,
        cultivoId: cultivoId,
        etapaFenologicaId: etapa,
        tipoSueloId: tipoSueloId,
      );

      resumenDias.add(
        DiaResumenSemanal(
          fecha: dia.fecha,
          nivelRiesgo: reglaDelDia?.nivelRiesgo ?? 'Bajo',
          temperaturaMax: dia.temperaturaMax,
          temperaturaMin: dia.temperaturaMin,
          precipitacion: dia.precipitacion,
        ),
      );

      if (reglaDelDia != null) {
        final p = prioridad(reglaDelDia.nivelRiesgo);
        if (p > prioridadMaxima) {
          prioridadMaxima = p;
          reglaPeorDia = reglaDelDia;
          diaMasCritico = dia.fecha;
        }
      }
    }

    if (reglaPeorDia == null) {
      return ResumenSemanal(
        dias: resumenDias,
        nivelRiesgoMaximo: 'Bajo',
        descripcionAlerta:
            'Semana sin riesgos climáticos relevantes previstos.',
        accionesDeLaSemana: const [
          'Continuar con el manejo habitual del cultivo',
        ],
      );
    }

    return ResumenSemanal(
      dias: resumenDias,
      nivelRiesgoMaximo: reglaPeorDia.nivelRiesgo,
      diaMasCritico: diaMasCritico,
      descripcionAlerta: reglaPeorDia.descripcionAlerta,
      accionesDeLaSemana: reglaPeorDia.acciones,
    );
  }
}
