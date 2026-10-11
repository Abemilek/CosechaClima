import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../clima/open_meteo_client.dart';

/// Caché de series de clima por ubicación (coordenadas redondeadas a 2 decimales,
/// ~1 km, que es la resolución útil de Open-Meteo). Permite:
/// - no repetir la descarga si el dato tiene menos de [frescura];
/// - seguir mostrando datos sin conexión hasta [vigenciaMaxima].
class ForecastCache {
  static const frescura = Duration(hours: 2);
  static const vigenciaMaxima = Duration(days: 3);
  static const _maxUbicaciones = 12;
  static const _claveIndice = 'forecast_indice';

  static String clave(double latitud, double longitud) =>
      'forecast_${latitud.toStringAsFixed(2)}_${longitud.toStringAsFixed(2)}';

  Future<SerieClima?> leer(double latitud, double longitud) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave(latitud, longitud));
      if (crudo == null) return null;
      final json = jsonDecode(crudo) as Map<String, dynamic>;
      return SerieClima(
        descargadaEn: DateTime.parse(json['descargadaEn'] as String),
        diasPasados: json['diasPasados'] as int,
        dias: (json['dias'] as List<dynamic>)
            .map((e) => DiaClima.fromJson(e as Map<String, dynamic>))
            .toList(),
        desdeCache: true,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(
    double latitud,
    double longitud,
    SerieClima serie,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final k = clave(latitud, longitud);
      await prefs.setString(
        k,
        jsonEncode({
          'descargadaEn': serie.descargadaEn.toIso8601String(),
          'diasPasados': serie.diasPasados,
          'dias': serie.dias.map((d) => d.toJson()).toList(),
        }),
      );

      // Índice con las ubicaciones más recientes: evita que la caché crezca sin límite.
      final indice = (prefs.getStringList(_claveIndice) ?? <String>[])
        ..remove(k)
        ..add(k);
      while (indice.length > _maxUbicaciones) {
        await prefs.remove(indice.removeAt(0));
      }
      await prefs.setStringList(_claveIndice, indice);
    } catch (_) {
      // La caché es opcional: si falla, la app sigue funcionando.
    }
  }
}
