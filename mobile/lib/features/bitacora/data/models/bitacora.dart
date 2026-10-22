class BitacoraEntry {
  final String id;
  final String parcelaId;
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

  const BitacoraEntry({
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
    id: json['id'] as String,
    parcelaId: json['parcelaId'] as String,
    fecha: DateTime.parse(json['fecha'] as String).toLocal(),
    eventoClimaticoId: (json['eventoClimaticoId'] as num).toInt(),
    nivelRiesgo: json['nivelRiesgo'] as String? ?? 'Bajo',
    accion1Texto: json['accion1Texto'] as String? ?? '',
    accion2Texto: json['accion2Texto'] as String? ?? '',
    accion3Texto: json['accion3Texto'] as String? ?? '',
    accion1Completada: json['accion1Completada'] as bool? ?? false,
    accion2Completada: json['accion2Completada'] as bool? ?? false,
    accion3Completada: json['accion3Completada'] as bool? ?? false,
    notas: json['notas'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcelaId': parcelaId,
    'fecha': fecha.toIso8601String(),
    'eventoClimaticoId': eventoClimaticoId,
    'nivelRiesgo': nivelRiesgo,
    'accion1Texto': accion1Texto,
    'accion2Texto': accion2Texto,
    'accion3Texto': accion3Texto,
    'accion1Completada': accion1Completada,
    'accion2Completada': accion2Completada,
    'accion3Completada': accion3Completada,
    'notas': notas,
  };

  BitacoraEntry copyWith({
    bool? accion1Completada,
    bool? accion2Completada,
    bool? accion3Completada,
    String? notas,
  }) => BitacoraEntry(
    id: id,
    parcelaId: parcelaId,
    fecha: fecha,
    eventoClimaticoId: eventoClimaticoId,
    nivelRiesgo: nivelRiesgo,
    accion1Texto: accion1Texto,
    accion2Texto: accion2Texto,
    accion3Texto: accion3Texto,
    accion1Completada: accion1Completada ?? this.accion1Completada,
    accion2Completada: accion2Completada ?? this.accion2Completada,
    accion3Completada: accion3Completada ?? this.accion3Completada,
    notas: notas ?? this.notas,
  );

  bool completada(int numero) => switch (numero) {
    1 => accion1Completada,
    2 => accion2Completada,
    3 => accion3Completada,
    _ => false,
  };
}

class BitacoraRequest {
  final String parcelaId;
  final DateTime fecha;
  final int eventoClimaticoId;
  final String nivelRiesgo;
  final String accion1Texto;
  final String accion2Texto;
  final String accion3Texto;
  final String? notas;

  const BitacoraRequest({
    required this.parcelaId,
    required this.fecha,
    required this.eventoClimaticoId,
    required this.nivelRiesgo,
    required this.accion1Texto,
    required this.accion2Texto,
    required this.accion3Texto,
    this.notas,
  });
}
