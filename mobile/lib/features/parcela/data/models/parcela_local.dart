/// Parcela guardada únicamente en el teléfono.
///
/// A diferencia del modelo anterior de "invitado", esta es la única parcela de
/// la app: no hay id de servidor ni usuario. [id] es estable y se usa para
/// relacionar la bitácora, el plan semanal y las copias de seguridad.
class ParcelaLocal {
  final String id;
  final int cultivoId;
  final String cultivoNombre;
  final int tipoSueloId;
  final String tipoSueloNombre;
  final int? etapaFenologicaId;
  final double latitud;
  final double longitud;
  final String? municipio;
  final String? comunidad;
  final DateTime fechaSiembra;
  final double areaMzs;
  final DateTime creadaEn;
  final DateTime actualizadaEn;

  const ParcelaLocal({
    required this.id,
    required this.cultivoId,
    required this.cultivoNombre,
    required this.tipoSueloId,
    required this.tipoSueloNombre,
    this.etapaFenologicaId,
    required this.latitud,
    required this.longitud,
    this.municipio,
    this.comunidad,
    required this.fechaSiembra,
    required this.areaMzs,
    required this.creadaEn,
    required this.actualizadaEn,
  });

  String get ubicacionTexto {
    final partes = [
      if (municipio != null && municipio!.trim().isNotEmpty) municipio!,
      if (comunidad != null && comunidad!.trim().isNotEmpty) comunidad!,
    ];
    return partes.isEmpty ? 'Ubicación GPS' : partes.join(' · ');
  }

  Map<String, dynamic> toJson() => {
    'idLocal': id,
    'cultivoId': cultivoId,
    'cultivoNombre': cultivoNombre,
    'tipoSueloId': tipoSueloId,
    'tipoSueloNombre': tipoSueloNombre,
    'etapaFenologicaId': etapaFenologicaId,
    'latitud': latitud,
    'longitud': longitud,
    'municipio': municipio,
    'comunidad': comunidad,
    'fechaSiembra': fechaSiembra.toIso8601String(),
    'areaMzs': areaMzs,
    'creadaEn': creadaEn.toIso8601String(),
    'actualizadaEn': actualizadaEn.toIso8601String(),
  };

  factory ParcelaLocal.fromJson(Map<String, dynamic> json) {
    final creadaEn =
        DateTime.tryParse(json['creadaEn'] as String? ?? '') ?? DateTime.now();
    return ParcelaLocal(
      id: '${json['idLocal'] ?? json['id']}',
      cultivoId: (json['cultivoId'] as num).toInt(),
      cultivoNombre: json['cultivoNombre'] as String? ?? 'Cultivo',
      tipoSueloId: (json['tipoSueloId'] as num).toInt(),
      tipoSueloNombre: json['tipoSueloNombre'] as String? ?? 'Suelo',
      etapaFenologicaId: (json['etapaFenologicaId'] as num?)?.toInt(),
      latitud: (json['latitud'] as num).toDouble(),
      longitud: (json['longitud'] as num).toDouble(),
      municipio: json['municipio'] as String?,
      comunidad: json['comunidad'] as String?,
      fechaSiembra: DateTime.parse(json['fechaSiembra'] as String),
      areaMzs: (json['areaMzs'] as num).toDouble(),
      creadaEn: creadaEn,
      actualizadaEn:
          DateTime.tryParse(json['actualizadaEn'] as String? ?? '') ?? creadaEn,
    );
  }
}
