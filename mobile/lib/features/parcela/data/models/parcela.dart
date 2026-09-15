class Parcela {
  final int id;
  final int usuarioId;
  final int cultivoId;
  final int? etapaFenologicaId;
  final int tipoSueloId;
  final DateTime fechaSiembra;
  final double areaMzs;
  final double? latitud;
  final double? longitud;
  final String? municipio;
  final String? comunidad;
  final bool activa;

  Parcela({
    required this.id,
    required this.usuarioId,
    required this.cultivoId,
    this.etapaFenologicaId,
    required this.tipoSueloId,
    required this.fechaSiembra,
    required this.areaMzs,
    this.latitud,
    this.longitud,
    this.municipio,
    this.comunidad,
    required this.activa,
  });

  bool get tieneCoordenadas => latitud != null && longitud != null;

  factory Parcela.fromJson(Map<String, dynamic> json) => Parcela(
    id: json['id'] as int,
    usuarioId: json['usuarioId'] as int,
    cultivoId: json['cultivoId'] as int,
    etapaFenologicaId: json['etapaFenologicaId'] as int?,
    tipoSueloId: json['tipoSueloId'] as int,
    fechaSiembra: DateTime.parse(json['fechaSiembra'] as String),
    areaMzs: (json['areaMzs'] as num).toDouble(),
    latitud: (json['latitud'] as num?)?.toDouble(),
    longitud: (json['longitud'] as num?)?.toDouble(),
    municipio: json['municipio'] as String?,
    comunidad: json['comunidad'] as String?,
    activa: json['activa'] as bool? ?? true,
  );
}

class ParcelaRequest {
  final int cultivoId;
  final int? etapaFenologicaId;
  final int tipoSueloId;
  final DateTime fechaSiembra;
  final double areaMzs;
  final double? latitud;
  final double? longitud;
  final String? municipio;
  final String? comunidad;

  ParcelaRequest({
    required this.cultivoId,
    this.etapaFenologicaId,
    required this.tipoSueloId,
    required this.fechaSiembra,
    required this.areaMzs,
    this.latitud,
    this.longitud,
    this.municipio,
    this.comunidad,
  });

  Map<String, dynamic> toJson() => {
    'cultivoId': cultivoId,
    if (etapaFenologicaId != null) 'etapaFenologicaId': etapaFenologicaId,
    'tipoSueloId': tipoSueloId,
    'fechaSiembra':
        '${fechaSiembra.year.toString().padLeft(4, '0')}-'
        '${fechaSiembra.month.toString().padLeft(2, '0')}-'
        '${fechaSiembra.day.toString().padLeft(2, '0')}',
    'areaMzs': areaMzs,
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
    if (municipio != null) 'municipio': municipio,
    if (comunidad != null) 'comunidad': comunidad,
  };
}

class ParcelaUpdateRequest {
  final double? latitud;
  final double? longitud;
  final double? areaMzs;
  final String? municipio;
  final String? comunidad;

  const ParcelaUpdateRequest({
    this.latitud,
    this.longitud,
    this.areaMzs,
    this.municipio,
    this.comunidad,
  });

  bool get estaVacio =>
      latitud == null &&
      longitud == null &&
      areaMzs == null &&
      municipio == null &&
      comunidad == null;

  Map<String, dynamic> toJson() => {
    if (latitud != null) 'latitud': latitud,
    if (longitud != null) 'longitud': longitud,
    if (areaMzs != null) 'areaMzs': areaMzs,
    if (municipio != null) 'municipio': municipio,
    if (comunidad != null) 'comunidad': comunidad,
  };
}
