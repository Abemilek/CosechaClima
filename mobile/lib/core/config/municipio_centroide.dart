class MunicipioCentroide {
  MunicipioCentroide._();

  static const _carazo = <String, (double, double)>{
    'Diriamba': (11.850, -86.233),
    'Jinotepe': (11.850, -86.200),
    'San Marcos': (11.917, -86.200),
    'Dolores': (11.850, -86.217),
    'El Rosario': (11.833, -86.167),
    'La Conquista': (11.733, -86.200),
    'La Paz de Carazo': (11.817, -86.133),
    'Santa Teresa': (11.733, -86.217),
  };

  static const _departamentos = <String, (double, double)>{
    'Boaco': (12.472, -85.662),
    'Carazo': (11.850, -86.200),
    'Chinandega': (12.630, -87.130),
    'Chontales': (12.097, -85.367),
    'Estelí': (13.091, -86.354),
    'Granada': (11.930, -85.956),
    'Jinotega': (13.092, -85.999),
    'León': (12.434, -86.878),
    'Madriz': (13.469, -86.587),
    'Managua': (12.136, -86.251),
    'Masaya': (11.974, -86.094),
    'Matagalpa': (12.925, -85.918),
    'Nueva Segovia': (13.633, -86.483),
    'Rivas': (11.439, -85.828),
    'Río San Juan': (11.123, -84.776),
    'Región Autónoma de la Costa Caribe Norte': (14.033, -83.383),
    'Región Autónoma de la Costa Caribe Sur': (11.994, -83.756),
  };

  static final _porNombre = <String, (double, double)>{
    ..._carazo,
    ..._departamentos,
  };

  static (double, double)? _centroide(String? municipio) {
    final nombre = municipio?.trim();
    if (nombre == null || nombre.isEmpty) return null;
    final directo = _porNombre[nombre];
    if (directo != null) return directo;
    final minuscula = nombre.toLowerCase();
    for (final entrada in _porNombre.entries) {
      if (entrada.key.toLowerCase() == minuscula) return entrada.value;
    }
    return null;
  }

  static double? latitud(String? municipio) => _centroide(municipio)?.$1;

  static double? longitud(String? municipio) => _centroide(municipio)?.$2;

  static bool conocido(String? municipio) => _centroide(municipio) != null;

  static String? masCercano(double latitud, double longitud) {
    String? mejor;
    var mejorDistancia = double.infinity;
    for (final entrada in _porNombre.entries) {
      final dLat = entrada.value.$1 - latitud;
      final dLon = entrada.value.$2 - longitud;
      final distancia = dLat * dLat + dLon * dLon;
      if (distancia < mejorDistancia) {
        mejorDistancia = distancia;
        mejor = entrada.key;
      }
    }
    return mejor;
  }
}
