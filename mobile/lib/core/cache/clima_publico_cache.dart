import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/clima/data/models/clima.dart';

class CachedPronosticoPublico {
  final List<PronosticoPublico> pronostico;
  final String ubicacionTexto;
  final DateTime guardadoEn;

  const CachedPronosticoPublico({
    required this.pronostico,
    required this.ubicacionTexto,
    required this.guardadoEn,
  });
}

class ClimaPublicoCache {
  static const _clave = 'cache_pronostico_publico';
  static const _maxEntradas = 4;

  static String _llave(double latitud, double longitud) =>
      '${latitud.toStringAsFixed(1)}_${longitud.toStringAsFixed(1)}';

  Future<void> guardar({
    required double latitud,
    required double longitud,
    required String ubicacionTexto,
    required List<PronosticoPublico> pronostico,
  }) async {
    if (pronostico.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final entradas = _leer(prefs);
      entradas[_llave(latitud, longitud)] = {
        'ubicacionTexto': ubicacionTexto,
        'guardadoEn': DateTime.now().toIso8601String(),
        'pronostico': pronostico.map((d) => d.toJson()).toList(),
      };
      await prefs.setString(_clave, jsonEncode(_podar(entradas)));
    } catch (_) {}
  }

  Future<CachedPronosticoPublico?> obtener({
    double? latitud,
    double? longitud,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entradas = _leer(prefs);
      if (entradas.isEmpty) return null;

      if (latitud != null && longitud != null) {
        final exacta = _parsear(entradas[_llave(latitud, longitud)]);
        if (exacta != null) return exacta;
      }

      final ordenadas = entradas.entries.toList()
        ..sort(
          (a, b) => _guardadoEnDe(b.value).compareTo(_guardadoEnDe(a.value)),
        );
      return _parsear(ordenadas.first.value);
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }

  Map<String, Map<String, dynamic>> _leer(SharedPreferences prefs) {
    final crudo = prefs.getString(_clave);
    if (crudo == null || crudo.isEmpty) return {};
    try {
      final decoded = jsonDecode(crudo) as Map<String, dynamic>;
      return decoded.map(
        (clave, valor) =>
            MapEntry(clave, Map<String, dynamic>.from(valor as Map)),
      );
    } catch (_) {
      return {};
    }
  }

  Map<String, Map<String, dynamic>> _podar(
    Map<String, Map<String, dynamic>> entradas,
  ) {
    if (entradas.length <= _maxEntradas) return entradas;
    final ordenadas = entradas.entries.toList()
      ..sort(
        (a, b) => _guardadoEnDe(b.value).compareTo(_guardadoEnDe(a.value)),
      );
    return {for (final e in ordenadas.take(_maxEntradas)) e.key: e.value};
  }

  static DateTime _guardadoEnDe(Map<String, dynamic> entrada) =>
      DateTime.tryParse(entrada['guardadoEn'] as String? ?? '') ??
      DateTime.fromMillisecondsSinceEpoch(0);

  CachedPronosticoPublico? _parsear(Map<String, dynamic>? entrada) {
    if (entrada == null) return null;
    try {
      final dias = (entrada['pronostico'] as List<dynamic>)
          .map((e) => PronosticoPublico.fromJson(e as Map<String, dynamic>))
          .toList();
      final guardadoEn = DateTime.tryParse(
        entrada['guardadoEn'] as String? ?? '',
      );
      if (dias.isEmpty || guardadoEn == null) return null;
      return CachedPronosticoPublico(
        pronostico: dias,
        ubicacionTexto: entrada['ubicacionTexto'] as String? ?? 'Tu zona',
        guardadoEn: guardadoEn,
      );
    } catch (_) {
      return null;
    }
  }
}
