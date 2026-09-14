class BitacoraEntry {
  final int id;
  final int parcelaId;
  final DateTime fecha;
  final int eventoClimaticoId;
  final String nivelRiesgo;
  final String accion1Texto;
  final String accion2Texto;
  final String accion3Texto;
  final bool accion1Completada;
  final bool accion2Completada;
  final bool accion3Completada;
  final String? notas;

  BitacoraEntry({
    required this.id,
    required this.parcelaId,
    required this.fecha,
    required this.eventoClimaticoId,
    required this.nivelRiesgo,
    required this.accion1Texto,
    required this.accion2Texto,
    required this.accion3Texto,
    required this.accion1Completada,
    required this.accion2Completada,
    required this.accion3Completada,
    this.notas,
  });

  factory BitacoraEntry.fromJson(Map<String, dynamic> json) => BitacoraEntry(
    id: json['id'] as int,
    parcelaId: json['parcelaId'] as int,
    fecha: DateTime.parse(json['fecha'] as String),
    eventoClimaticoId: json['eventoClimaticoId'] as int,
    nivelRiesgo: json['nivelRiesgo'] as String,
    accion1Texto: json['accion1Texto'] as String? ?? '',
    accion2Texto: json['accion2Texto'] as String? ?? '',
    accion3Texto: json['accion3Texto'] as String? ?? '',
    accion1Completada: json['accion1Completada'] as bool? ?? false,
    accion2Completada: json['accion2Completada'] as bool? ?? false,
    accion3Completada: json['accion3Completada'] as bool? ?? false,
    notas: json['notas'] as String?,
  );
}

class BitacoraRequest {
  final int parcelaId;
  final DateTime fecha;
  final int eventoClimaticoId;
  final String nivelRiesgo;
  final String accion1Texto;
  final String accion2Texto;
  final String accion3Texto;
  final String? notas;

  BitacoraRequest({
    required this.parcelaId,
    required this.fecha,
    required this.eventoClimaticoId,
    required this.nivelRiesgo,
    required this.accion1Texto,
    required this.accion2Texto,
    required this.accion3Texto,
    this.notas,
  });

  Map<String, dynamic> toJson() => {
    'parcelaId': parcelaId,
    'fecha':
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}',
    'eventoClimaticoId': eventoClimaticoId,
    'nivelRiesgo': nivelRiesgo,
    'accion1Texto': accion1Texto,
    'accion2Texto': accion2Texto,
    'accion3Texto': accion3Texto,
    if (notas != null) 'notas': notas,
  };
}
