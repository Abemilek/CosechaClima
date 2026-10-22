import '../../../../core/motor/motor_local.dart';

/// Preferencias de alerta del productor. Se guardan en el teléfono.
class UmbralConfig {
  final int lluviaIntensaMm;
  final int vientoFuerteKmh;
  final int caniculaDias;
  final String variedadCultivo;
  final bool tieneRiego;
  final String horarioSms;

  const UmbralConfig({
    this.lluviaIntensaMm = 100,
    this.vientoFuerteKmh = 40,
    this.caniculaDias = 7,
    this.variedadCultivo = 'Criollo',
    this.tieneRiego = false,
    this.horarioSms = '06:00',
  });

  static const recomendado = UmbralConfig();

  UmbralesMotor aMotor() => UmbralesMotor(
    lluviaIntensaMm: lluviaIntensaMm,
    vientoFuerteKmh: vientoFuerteKmh,
    caniculaDias: caniculaDias,
  );

  UmbralConfig copyWith({
    int? lluviaIntensaMm,
    int? vientoFuerteKmh,
    int? caniculaDias,
    String? variedadCultivo,
    bool? tieneRiego,
    String? horarioSms,
  }) => UmbralConfig(
    lluviaIntensaMm: lluviaIntensaMm ?? this.lluviaIntensaMm,
    vientoFuerteKmh: vientoFuerteKmh ?? this.vientoFuerteKmh,
    caniculaDias: caniculaDias ?? this.caniculaDias,
    variedadCultivo: variedadCultivo ?? this.variedadCultivo,
    tieneRiego: tieneRiego ?? this.tieneRiego,
    horarioSms: horarioSms ?? this.horarioSms,
  );

  Map<String, dynamic> toJson() => {
    'lluviaIntensaMm': lluviaIntensaMm,
    'vientoFuerteKmh': vientoFuerteKmh,
    'caniculaDias': caniculaDias,
    'variedadCultivo': variedadCultivo,
    'tieneRiego': tieneRiego,
    'horarioSms': horarioSms,
  };

  factory UmbralConfig.fromJson(Map<String, dynamic> json) => UmbralConfig(
    lluviaIntensaMm: (json['lluviaIntensaMm'] as num?)?.toInt() ?? 100,
    vientoFuerteKmh: (json['vientoFuerteKmh'] as num?)?.toInt() ?? 40,
    caniculaDias: (json['caniculaDias'] as num?)?.toInt() ?? 7,
    variedadCultivo: json['variedadCultivo'] as String? ?? 'Criollo',
    tieneRiego: json['tieneRiego'] as bool? ?? false,
    horarioSms: json['horarioSms'] as String? ?? '06:00',
  );
}
