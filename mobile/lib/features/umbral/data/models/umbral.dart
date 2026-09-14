class Umbral {
  final int id;
  final int lluviaIntensaMm;
  final int vientoFuerteKmh;
  final int caniculaDias;
  final String variedadCultivo;
  final bool tieneRiego;
  final String horarioSms;

  Umbral({
    required this.id,
    required this.lluviaIntensaMm,
    required this.vientoFuerteKmh,
    required this.caniculaDias,
    required this.variedadCultivo,
    required this.tieneRiego,
    required this.horarioSms,
  });

  factory Umbral.fromJson(Map<String, dynamic> json) => Umbral(
    id: json['id'] as int,
    lluviaIntensaMm: json['lluviaIntensaMm'] as int,
    vientoFuerteKmh: json['vientoFuerteKmh'] as int,
    caniculaDias: json['caniculaDias'] as int,
    variedadCultivo: json['variedadCultivo'] as String? ?? 'Criollo',
    tieneRiego: json['tieneRiego'] as bool? ?? false,
    horarioSms: (json['horarioSms'] as String).substring(0, 5),
  );
}

class UmbralRequest {
  final int lluviaIntensaMm;
  final int vientoFuerteKmh;
  final int caniculaDias;
  final String variedadCultivo;
  final bool tieneRiego;
  final String horarioSms;

  UmbralRequest({
    this.lluviaIntensaMm = 100,
    this.vientoFuerteKmh = 40,
    this.caniculaDias = 7,
    this.variedadCultivo = 'Criollo',
    this.tieneRiego = false,
    required this.horarioSms,
  });

  Map<String, dynamic> toJson() => {
    'lluviaIntensaMm': lluviaIntensaMm,
    'vientoFuerteKmh': vientoFuerteKmh,
    'caniculaDias': caniculaDias,
    'variedadCultivo': variedadCultivo,
    'tieneRiego': tieneRiego,
    'horarioSms': horarioSms,
  };
}
