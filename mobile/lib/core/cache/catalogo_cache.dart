import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/catalogo/data/models/catalogo.dart';

class CatalogoCache {
  static const _claveCultivos = 'cache_catalogo_cultivos';
  static const _claveSuelos = 'cache_catalogo_suelos';
  static const _claveEtapas = 'cache_catalogo_etapas';
  static const _claveEventos = 'cache_catalogo_eventos';

  Future<void> guardarCultivos(List<Cultivo> cultivos) =>
      _guardar(_claveCultivos, cultivos.map((e) => e.toJson()).toList());

  Future<void> guardarTiposSuelo(List<TipoSuelo> suelos) =>
      _guardar(_claveSuelos, suelos.map((e) => e.toJson()).toList());

  Future<void> guardarEtapas(List<EtapaFenologica> etapas) =>
      _guardar(_claveEtapas, etapas.map((e) => e.toJson()).toList());

  Future<void> guardarEventos(List<EventoClimatico> eventos) =>
      _guardar(_claveEventos, eventos.map((e) => e.toJson()).toList());

  Future<List<Cultivo>?> obtenerCultivos() async => (await _obtener(
    _claveCultivos,
  ))?.map((e) => Cultivo.fromJson(e)).toList();

  Future<List<TipoSuelo>?> obtenerTiposSuelo() async => (await _obtener(
    _claveSuelos,
  ))?.map((e) => TipoSuelo.fromJson(e)).toList();

  Future<List<EtapaFenologica>?> obtenerEtapas() async => (await _obtener(
    _claveEtapas,
  ))?.map((e) => EtapaFenologica.fromJson(e)).toList();

  Future<List<EventoClimatico>?> obtenerEventos() async => (await _obtener(
    _claveEventos,
  ))?.map((e) => EventoClimatico.fromJson(e)).toList();

  Future<void> limpiar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_claveCultivos);
      await prefs.remove(_claveSuelos);
      await prefs.remove(_claveEtapas);
      await prefs.remove(_claveEventos);
    } catch (_) {}
  }

  Future<void> _guardar(String clave, List<Map<String, dynamic>> items) async {
    if (items.isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(clave, jsonEncode(items));
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>?> _obtener(String clave) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null || crudo.isEmpty) return null;
      final decoded = jsonDecode(crudo) as List<dynamic>;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return null;
    }
  }
}
