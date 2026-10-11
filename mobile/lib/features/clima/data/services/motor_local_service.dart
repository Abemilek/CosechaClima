import 'dart:async';
import 'dart:math' as math;

import '../../../../core/cache/forecast_cache.dart';
import '../../../../core/cache/guest_parcela_store.dart';
import '../../../../core/clima/open_meteo_client.dart';
import '../../../../core/config/municipio_centroide.dart';
import '../../../../core/motor/motor_local.dart';
import '../../../../core/motor/reglas_repository.dart';
import '../../../../core/network/api_exception.dart';
import '../../../parcela/data/models/parcela.dart';
import '../models/clima.dart';

/// Lo mínimo que el motor necesita saber de una parcela (sirve para parcelas
/// con cuenta y para las de invitado).
class EntradaMotor {
  final int cultivoId;
  final int? etapaFenologicaId;
  final int tipoSueloId;
  final DateTime fechaSiembra;
  final double latitud;
  final double longitud;

  const EntradaMotor({
    required this.cultivoId,
    required this.etapaFenologicaId,
    required this.tipoSueloId,
    required this.fechaSiembra,
    required this.latitud,
    required this.longitud,
  });

  /// null si la parcela no tiene GPS ni un municipio reconocido para estimar la ubicación.
  static EntradaMotor? deParcela(Parcela parcela) {
    final double? lat;
    final double? lon;
    if (parcela.tieneCoordenadas) {
      lat = parcela.latitud;
      lon = parcela.longitud;
    } else {
      lat = MunicipioCentroide.latitud(parcela.municipio);
      lon = MunicipioCentroide.longitud(parcela.municipio);
    }
    if (lat == null || lon == null) return null;

    return EntradaMotor(
      cultivoId: parcela.cultivoId,
      etapaFenologicaId: parcela.etapaFenologicaId,
      tipoSueloId: parcela.tipoSueloId,
      fechaSiembra: parcela.fechaSiembra,
      latitud: lat,
      longitud: lon,
    );
  }

  factory EntradaMotor.deInvitado(GuestParcela parcela) => EntradaMotor(
    cultivoId: parcela.cultivoId,
    etapaFenologicaId: parcela.etapaFenologicaId,
    tipoSueloId: parcela.tipoSueloId,
    fechaSiembra: parcela.fechaSiembra,
    latitud: parcela.latitud,
    longitud: parcela.longitud,
  );
}

class EvaluacionLocal {
  final Semaforo semaforo;
  final ResumenSemanal resumen;
  final DatosClimaticos datosHoy;
  final DateTime descargadaEn;

  /// true si el clima salió de la copia guardada porque no hubo conexión.
  final bool desdeCache;

  const EvaluacionLocal({
    required this.semaforo,
    required this.resumen,
    required this.datosHoy,
    required this.descargadaEn,
    required this.desdeCache,
  });
}

/// Calcula semáforo y resumen semanal en el dispositivo:
/// clima directo de Open-Meteo (con caché) + reglas locales + [MotorLocal].
/// Sin conexión sigue funcionando con la última descarga (hasta 3 días).
class MotorLocalService {
  static const _diasPronostico = 8; // hoy + 7

  final OpenMeteoClient _clima;
  final ForecastCache _cache;
  final ReglasRepository _reglas;
  final DateTime Function() _ahora;

  MotorLocalService({
    OpenMeteoClient? clima,
    ForecastCache? cache,
    ReglasRepository? reglas,
    DateTime Function()? ahora,
  }) : _clima = clima ?? OpenMeteoClient(),
       _cache = cache ?? ForecastCache(),
       _reglas = reglas ?? ReglasRepository.instancia,
       _ahora = ahora ?? DateTime.now;

  Future<EvaluacionLocal> evaluar(
    EntradaMotor entrada, {
    UmbralesMotor umbrales = const UmbralesMotor(),
  }) async {
    final paquete = await _reglas.obtener();
    final serie = await _obtenerSerie(
      entrada.latitud,
      entrada.longitud,
      diasPasados: umbrales.diasCanicula,
      diasPronostico: _diasPronostico,
    );
    final hoy = _hoy();

    final semaforo = MotorLocal.semaforoDeHoy(
      paquete: paquete,
      serie: serie,
      hoy: hoy,
      cultivoId: entrada.cultivoId,
      etapaFenologicaId: entrada.etapaFenologicaId,
      tipoSueloId: entrada.tipoSueloId,
      fechaSiembra: entrada.fechaSiembra,
      umbrales: umbrales,
    );

    final resumen = MotorLocal.resumenSemanal(
      paquete: paquete,
      serie: serie,
      hoy: hoy,
      cultivoId: entrada.cultivoId,
      etapaFenologicaId: entrada.etapaFenologicaId,
      tipoSueloId: entrada.tipoSueloId,
      fechaSiembra: entrada.fechaSiembra,
      umbrales: umbrales,
    );

    final dia = serie.dias[serie.indiceDe(hoy)!];
    return EvaluacionLocal(
      semaforo: semaforo,
      resumen: resumen,
      datosHoy: DatosClimaticos(
        id: 0,
        parcelaId: 0,
        fecha: dia.fecha,
        temperaturaMax: dia.temperaturaMax,
        temperaturaMin: dia.temperaturaMin,
        precipitacion: dia.precipitacion,
        vientoVelocidad: dia.vientoVelocidad,
        humedadRelativa: dia.humedadRelativa,
        fuenteClima: 'OPEN_METEO',
      ),
      descargadaEn: serie.descargadaEn,
      desdeCache: serie.desdeCache,
    );
  }

  /// Solo el resumen semanal (modo invitado: umbrales por defecto).
  Future<({ResumenSemanal resumen, DateTime descargadaEn, bool desdeCache})>
  resumenSemanal(
    EntradaMotor entrada, {
    UmbralesMotor umbrales = const UmbralesMotor(),
  }) async {
    final paquete = await _reglas.obtener();
    final serie = await _obtenerSerie(
      entrada.latitud,
      entrada.longitud,
      diasPasados: umbrales.diasCanicula,
      diasPronostico: _diasPronostico,
    );

    final resumen = MotorLocal.resumenSemanal(
      paquete: paquete,
      serie: serie,
      hoy: _hoy(),
      cultivoId: entrada.cultivoId,
      etapaFenologicaId: entrada.etapaFenologicaId,
      tipoSueloId: entrada.tipoSueloId,
      fechaSiembra: entrada.fechaSiembra,
      umbrales: umbrales,
    );
    return (
      resumen: resumen,
      descargadaEn: serie.descargadaEn,
      desdeCache: serie.desdeCache,
    );
  }

  /// Pronóstico de 5 días para la pantalla pública (sin parcela ni cuenta).
  Future<List<PronosticoPublico>> pronosticoPublico({
    required double latitud,
    required double longitud,
  }) async {
    final serie = await _obtenerSerie(
      latitud,
      longitud,
      diasPasados: 0,
      diasPronostico: 5,
    );
    final inicio = serie.indiceDe(_hoy()) ?? 0;
    final fin = math.min(inicio + 5, serie.dias.length);

    return [
      for (final dia in serie.dias.sublist(inicio, fin))
        PronosticoPublico(
          fecha: dia.fecha,
          temperaturaMax: dia.temperaturaMax,
          temperaturaMin: dia.temperaturaMin,
          precipitacion: dia.precipitacion,
          vientoVelocidad: dia.vientoVelocidad,
        ),
    ];
  }

  DateTime _hoy() {
    final ahora = _ahora();
    return DateTime(ahora.year, ahora.month, ahora.day);
  }

  Future<SerieClima> _obtenerSerie(
    double latitud,
    double longitud, {
    required int diasPasados,
    required int diasPronostico,
  }) async {
    final hoy = _hoy();
    final pasadosNecesarios = math.min(
      math.max(diasPasados, 2),
      OpenMeteoClient.maxDiasPasados,
    );

    final guardada = await _cache.leer(latitud, longitud);

    // Copia reciente y suficiente (cubre hoy y los días pasados pedidos): no hace falta red.
    if (guardada != null &&
        guardada.diasPasados >= pasadosNecesarios &&
        _ahora().difference(guardada.descargadaEn) < ForecastCache.frescura &&
        guardada.indiceDe(hoy) != null) {
      return guardada;
    }

    SerieClima? usable() {
      if (guardada == null) return null;
      final edad = _ahora().difference(guardada.descargadaEn);
      if (edad > ForecastCache.vigenciaMaxima) return null;
      return guardada.indiceDe(hoy) == null ? null : guardada;
    }

    try {
      final nueva = await _clima.obtener(
        latitud: latitud,
        longitud: longitud,
        diasPasados: pasadosNecesarios,
        diasPronostico: diasPronostico,
      );
      unawaited(_cache.guardar(latitud, longitud, nueva));
      return nueva;
    } on NetworkException {
      final respaldo = usable();
      if (respaldo != null) return respaldo;
      rethrow;
    } on TimeoutApiException {
      final respaldo = usable();
      if (respaldo != null) return respaldo;
      rethrow;
    }
  }
}
