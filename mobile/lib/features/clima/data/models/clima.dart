class DatosClimaticos {
  final int id;
  final int parcelaId;
  final DateTime fecha;
  final double? temperaturaMax;
  final double? temperaturaMin;
  final double? precipitacion;
  final double? vientoVelocidad;
  final double? humedadRelativa;
  final String fuenteClima;

  DatosClimaticos({
    required this.id,
    required this.parcelaId,
    required this.fecha,
    this.temperaturaMax,
    this.temperaturaMin,
    this.precipitacion,
    this.vientoVelocidad,
    this.humedadRelativa,
    required this.fuenteClima,
  });

  factory DatosClimaticos.fromJson(Map<String, dynamic> json) =>
      DatosClimaticos(
        id: json['id'] as int,
        parcelaId: json['parcelaId'] as int,
        fecha: DateTime.parse(json['fecha'] as String),
        temperaturaMax: (json['temperaturaMax'] as num?)?.toDouble(),
        temperaturaMin: (json['temperaturaMin'] as num?)?.toDouble(),
        precipitacion: (json['precipitacion'] as num?)?.toDouble(),
        vientoVelocidad: (json['vientoVelocidad'] as num?)?.toDouble(),
        humedadRelativa: (json['humedadRelativa'] as num?)?.toDouble(),
        fuenteClima: json['fuenteClima'] as String? ?? 'OPEN_METEO',
      );
}

class Semaforo {
  final String nivelRiesgo;
  final String descripcionAlerta;
  final List<String> acciones;
  final DateTime fecha;

  Semaforo({
    required this.nivelRiesgo,
    required this.descripcionAlerta,
    required this.acciones,
    required this.fecha,
  });

  factory Semaforo.fromJson(Map<String, dynamic> json) => Semaforo(
    nivelRiesgo: json['nivelRiesgo'] as String,
    descripcionAlerta: json['descripcionAlerta'] as String,
    acciones: (json['acciones'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(),
    fecha: DateTime.parse(json['fecha'] as String),
  );
}
