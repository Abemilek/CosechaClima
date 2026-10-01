class Cultivo {
  final int id;
  final String nombre;
  final String? nombreCientifico;

  Cultivo({required this.id, required this.nombre, this.nombreCientifico});

  factory Cultivo.fromJson(Map<String, dynamic> json) => Cultivo(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    nombreCientifico: json['nombreCientifico'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'nombreCientifico': nombreCientifico,
  };
}

class TipoSuelo {
  final int id;
  final String nombre;
  final String? descripcion;

  TipoSuelo({required this.id, required this.nombre, this.descripcion});

  factory TipoSuelo.fromJson(Map<String, dynamic> json) => TipoSuelo(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    descripcion: json['descripcion'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
  };
}

class EtapaFenologica {
  final int id;
  final String nombre;
  final String? descripcion;
  final int? diasDesdeSiembra;

  EtapaFenologica({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.diasDesdeSiembra,
  });

  factory EtapaFenologica.fromJson(Map<String, dynamic> json) =>
      EtapaFenologica(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
        diasDesdeSiembra: json['diasDesdeSiembra'] as int?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
    'diasDesdeSiembra': diasDesdeSiembra,
  };
}

class EventoClimatico {
  final int id;
  final String nombre;
  final String? descripcion;

  EventoClimatico({required this.id, required this.nombre, this.descripcion});

  factory EventoClimatico.fromJson(Map<String, dynamic> json) =>
      EventoClimatico(
        id: json['id'] as int,
        nombre: json['nombre'] as String,
        descripcion: json['descripcion'] as String?,
      );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'descripcion': descripcion,
  };
}
