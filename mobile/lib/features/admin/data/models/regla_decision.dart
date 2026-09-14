class ReglaDecision {
  final int id;
  final int eventoClimaticoId;
  final int cultivoId;
  final int etapaFenologicaId;
  final int tipoSueloId;
  final String nivelRiesgo;
  final String accion1;
  final String accion2;
  final String accion3;
  final String descripcionAlerta;

  ReglaDecision({
    required this.id,
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

  factory ReglaDecision.fromJson(Map<String, dynamic> json) => ReglaDecision(
    id: json['id'] as int,
    eventoClimaticoId: json['eventoClimaticoId'] as int,
    cultivoId: json['cultivoId'] as int,
    etapaFenologicaId: json['etapaFenologicaId'] as int,
    tipoSueloId: json['tipoSueloId'] as int,
    nivelRiesgo: json['nivelRiesgo'] as String? ?? '',
    accion1: json['accion1'] as String? ?? '',
    accion2: json['accion2'] as String? ?? '',
    accion3: json['accion3'] as String? ?? '',
    descripcionAlerta: json['descripcionAlerta'] as String? ?? '',
  );
}
