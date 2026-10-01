import 'dart:async';

import '../../../../core/cache/catalogo_cache.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/catalogo.dart';

class CatalogoService {
  final ApiClient _client;
  final CatalogoCache _cache;

  CatalogoService(this._client, {CatalogoCache? cache})
    : _cache = cache ?? CatalogoCache();

  Future<List<Cultivo>> obtenerCultivos() async {
    try {
      final json = await _client.get('/catalogos/cultivos') as List<dynamic>;
      final cultivos = json
          .map((e) => Cultivo.fromJson(e as Map<String, dynamic>))
          .toList();
      unawaited(_cache.guardarCultivos(cultivos));
      return cultivos;
    } on NetworkException {
      final cache = await _cache.obtenerCultivos();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    } on TimeoutApiException {
      final cache = await _cache.obtenerCultivos();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    }
  }

  Future<List<TipoSuelo>> obtenerTiposSuelo() async {
    try {
      final json = await _client.get('/catalogos/tipos-suelo') as List<dynamic>;
      final suelos = json
          .map((e) => TipoSuelo.fromJson(e as Map<String, dynamic>))
          .toList();
      unawaited(_cache.guardarTiposSuelo(suelos));
      return suelos;
    } on NetworkException {
      final cache = await _cache.obtenerTiposSuelo();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    } on TimeoutApiException {
      final cache = await _cache.obtenerTiposSuelo();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    }
  }

  Future<List<EtapaFenologica>> obtenerEtapasFenologicas() async {
    try {
      final json =
          await _client.get('/catalogos/etapas-fenologicas') as List<dynamic>;
      final etapas = json
          .map((e) => EtapaFenologica.fromJson(e as Map<String, dynamic>))
          .toList();
      unawaited(_cache.guardarEtapas(etapas));
      return etapas;
    } on NetworkException {
      final cache = await _cache.obtenerEtapas();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    } on TimeoutApiException {
      final cache = await _cache.obtenerEtapas();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    }
  }

  Future<List<EventoClimatico>> obtenerEventosClimaticos() async {
    try {
      final json =
          await _client.get('/catalogos/eventos-climaticos') as List<dynamic>;
      final eventos = json
          .map((e) => EventoClimatico.fromJson(e as Map<String, dynamic>))
          .toList();
      unawaited(_cache.guardarEventos(eventos));
      return eventos;
    } on NetworkException {
      final cache = await _cache.obtenerEventos();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    } on TimeoutApiException {
      final cache = await _cache.obtenerEventos();
      if (cache != null && cache.isNotEmpty) return cache;
      rethrow;
    }
  }
}
