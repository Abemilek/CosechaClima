import '../../features/catalogo/data/models/catalogo.dart';

/// Regla agronómica: para un evento climático, cultivo, etapa y suelo,
/// qué nivel de riesgo es y qué debe hacer el productor.
class ReglaLocal {
  final int eventoClimaticoId;
  final int cultivoId;
  final int etapaFenologicaId;
  final int tipoSueloId;
  final String nivelRiesgo;
  final String accion1;
  final String accion2;
  final String accion3;
  final String descripcionAlerta;

  const ReglaLocal({
    required this.eventoClimaticoId,
    required this.cultivoId,
    required this.etapaFenologicaId,
    required this.tipoSueloId,
    required this.nivelRiesgo,
    required this.accion1,
    required this.accion2,
    required this.accion3,
    required this.descripcionAlerta,
  });

  factory ReglaLocal.fromJson(Map<String, dynamic> json) => ReglaLocal(
    eventoClimaticoId: json['eventoClimaticoId'] as int,
    cultivoId: json['cultivoId'] as int,
    etapaFenologicaId: json['etapaFenologicaId'] as int,
    tipoSueloId: json['tipoSueloId'] as int,
    nivelRiesgo: json['nivelRiesgo'] as String,
    accion1: json['accion1'] as String,
    accion2: json['accion2'] as String,
    accion3: json['accion3'] as String,
    descripcionAlerta: json['descripcionAlerta'] as String,
  );

  List<String> get acciones => [accion1, accion2, accion3];
}

/// Catálogos + reglas activas. Es el mismo contenido que sirve
/// GET /api/reglas/paquete, así que el teléfono puede calcular alertas
/// sin conexión. [version] identifica el contenido (hash del paquete).
class PaqueteReglas {
  final String version;
  final List<EventoClimatico> eventos;
  final List<Cultivo> cultivos;
  final List<TipoSuelo> tiposSuelo;
  final List<EtapaFenologica> etapas;
  final Map<(int, int, int, int), ReglaLocal> _indice;

  PaqueteReglas._({
    required this.version,
    required this.eventos,
    required this.cultivos,
    required this.tiposSuelo,
    required this.etapas,
    required this._indice,
  });

  factory PaqueteReglas.fromJson(Map<String, dynamic> json) {
    List<T> lista<T>(String clave, T Function(Map<String, dynamic>) mapear) =>
        (json[clave] as List<dynamic>)
            .map((e) => mapear(e as Map<String, dynamic>))
            .toList();

    final reglas = lista('reglas', ReglaLocal.fromJson);
    if (reglas.isEmpty) {
      throw const FormatException('El paquete de reglas no tiene reglas.');
    }

    final etapas = lista('etapas', EtapaFenologica.fromJson)
      ..sort(
        (a, b) => (a.diasDesdeSiembra ?? 0).compareTo(b.diasDesdeSiembra ?? 0),
      );

    return PaqueteReglas._(
      version: json['version'] as String,
      eventos: lista('eventos', EventoClimatico.fromJson),
      cultivos: lista('cultivos', Cultivo.fromJson),
      tiposSuelo: lista('tiposSuelo', TipoSuelo.fromJson),
      etapas: etapas,
      indice: {
        for (final r in reglas)
          (
            r.eventoClimaticoId,
            r.cultivoId,
            r.etapaFenologicaId,
            r.tipoSueloId,
          ): r,
      },
    );
  }

  int get totalReglas => _indice.length;

  /// Regla activa de la combinación, o null si no existe (o un admin la desactivó).
  ReglaLocal? buscar({
    required int eventoClimaticoId,
    required int cultivoId,
    required int etapaFenologicaId,
    required int tipoSueloId,
  }) => _indice[(eventoClimaticoId, cultivoId, etapaFenologicaId, tipoSueloId)];
}
