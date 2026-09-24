import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/clima/data/models/clima.dart';

class CachedParcelaClima {
  final DatosClimaticos clima;
  final Semaforo semaforo;
  final DateTime guardadoEn;

  const CachedParcelaClima({
    required this.clima,
    required this.semaforo,
    required this.guardadoEn,
  });
}

class ParcelaCache {
  static String _key(int parcelaId) => 'cache_clima_parcela_$parcelaId';

  Future<void> guardar({
    required int parcelaId,
    required DatosClimaticos clima,
    required Semaforo semaforo,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'clima': clima.toJson(),
        'semaforo': semaforo.toJson(),
        'guardadoEn': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_key(parcelaId), payload);
    } catch (_) {}
  }

  Future<CachedParcelaClima?> obtener(int parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_key(parcelaId));
      if (crudo == null || crudo.isEmpty) return null;

      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final climaJson = data['clima'] as Map<String, dynamic>?;
      final semaforoJson = data['semaforo'] as Map<String, dynamic>?;
      final guardadoEnCrudo = data['guardadoEn'] as String?;

      if (climaJson == null ||
          semaforoJson == null ||
          guardadoEnCrudo == null) {
        return null;
      }

      return CachedParcelaClima(
        clima: DatosClimaticos.fromJson(climaJson),
        semaforo: Semaforo.fromJson(semaforoJson),
        guardadoEn: DateTime.parse(guardadoEnCrudo),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar(int parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(parcelaId));
    } catch (_) {}
  }
}
