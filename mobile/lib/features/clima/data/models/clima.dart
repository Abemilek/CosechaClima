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

  Map<String, dynamic> toJson() => {
    'id': id,
    'parcelaId': parcelaId,
    'fecha': fecha.toIso8601String(),
    'temperaturaMax': temperaturaMax,
    'temperaturaMin': temperaturaMin,
    'precipitacion': precipitacion,
    'vientoVelocidad': vientoVelocidad,
    'humedadRelativa': humedadRelativa,
    'fuenteClima': fuenteClima,
  };
}

class Semaforo {
  final String nivelRiesgo;
  final String descripcionAlerta;
  final List<String> acciones;
  final DateTime fecha;
  final int eventoClimaticoId;

  Semaforo({
    required this.nivelRiesgo,
    required this.descripcionAlerta,
    required this.acciones,
    required this.fecha,
    required this.eventoClimaticoId,
  });

  factory Semaforo.fromJson(Map<String, dynamic> json) => Semaforo(
    nivelRiesgo: json['nivelRiesgo'] as String,
    descripcionAlerta: json['descripcionAlerta'] as String,
    acciones: (json['acciones'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(),
    fecha: DateTime.parse(json['fecha'] as String),
    eventoClimaticoId: json['eventoClimaticoId'] as int? ?? 0,
  );

  Map<String, dynamic> toJson() => {
    'nivelRiesgo': nivelRiesgo,
    'descripcionAlerta': descripcionAlerta,
    'acciones': acciones,
    'fecha': fecha.toIso8601String(),
    'eventoClimaticoId': eventoClimaticoId,
  };
}

class PronosticoPublico {
  final DateTime fecha;
  final double? temperaturaMax;
  final double? temperaturaMin;
  final double? precipitacion;
  final double? vientoVelocidad;

  PronosticoPublico({
    required this.fecha,
    this.temperaturaMax,
    this.temperaturaMin,
    this.precipitacion,
    this.vientoVelocidad,
  });

  factory PronosticoPublico.fromJson(Map<String, dynamic> json) =>
      PronosticoPublico(
        fecha: DateTime.parse(json['fecha'] as String),
        temperaturaMax: (json['temperaturaMax'] as num?)?.toDouble(),
        temperaturaMin: (json['temperaturaMin'] as num?)?.toDouble(),
        precipitacion: (json['precipitacion'] as num?)?.toDouble(),
        vientoVelocidad: (json['vientoVelocidad'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'fecha': fecha.toIso8601String(),
    'temperaturaMax': temperaturaMax,
    'temperaturaMin': temperaturaMin,
    'precipitacion': precipitacion,
    'vientoVelocidad': vientoVelocidad,
  };
}

class DiaResumenSemanal {
  final DateTime fecha;
  final String nivelRiesgo;
  final double? temperaturaMax;
  final double? temperaturaMin;
  final double? precipitacion;

  DiaResumenSemanal({
    required this.fecha,
    required this.nivelRiesgo,
    this.temperaturaMax,
    this.temperaturaMin,
    this.precipitacion,
  });

  factory DiaResumenSemanal.fromJson(Map<String, dynamic> json) =>
      DiaResumenSemanal(
        fecha: DateTime.parse(json['fecha'] as String),
        nivelRiesgo: json['nivelRiesgo'] as String,
        temperaturaMax: (json['temperaturaMax'] as num?)?.toDouble(),
        temperaturaMin: (json['temperaturaMin'] as num?)?.toDouble(),
        precipitacion: (json['precipitacion'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
    'fecha': fecha.toIso8601String(),
    'nivelRiesgo': nivelRiesgo,
    'temperaturaMax': temperaturaMax,
    'temperaturaMin': temperaturaMin,
    'precipitacion': precipitacion,
  };
}

class ResumenSemanal {
  final List<DiaResumenSemanal> dias;
  final String nivelRiesgoMaximo;
  final DateTime? diaMasCritico;
  final String descripcionAlerta;
  final List<String> accionesDeLaSemana;

  ResumenSemanal({
    required this.dias,
    required this.nivelRiesgoMaximo,
    this.diaMasCritico,
    required this.descripcionAlerta,
    required this.accionesDeLaSemana,
  });

  factory ResumenSemanal.fromJson(Map<String, dynamic> json) => ResumenSemanal(
    dias: (json['dias'] as List<dynamic>)
        .map((e) => DiaResumenSemanal.fromJson(e as Map<String, dynamic>))
        .toList(),
    nivelRiesgoMaximo: json['nivelRiesgoMaximo'] as String,
    diaMasCritico: json['diaMasCritico'] == null
        ? null
        : DateTime.parse(json['diaMasCritico'] as String),
    descripcionAlerta: json['descripcionAlerta'] as String,
    accionesDeLaSemana: (json['accionesDeLaSemana'] as List<dynamic>)
        .map((e) => e.toString())
        .toList(),
  );

  Map<String, dynamic> toJson() => {
    'dias': dias.map((d) => d.toJson()).toList(),
    'nivelRiesgoMaximo': nivelRiesgoMaximo,
    'diaMasCritico': diaMasCritico?.toIso8601String(),
    'descripcionAlerta': descripcionAlerta,
    'accionesDeLaSemana': accionesDeLaSemana,
  };
}
