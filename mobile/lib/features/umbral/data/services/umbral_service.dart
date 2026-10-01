import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/umbral.dart';

class UmbralService {
  final ApiClient _client;

  UmbralService(this._client);

  static const _clavePendientes = 'umbrales_pendientes';

  Future<Umbral?> obtenerMios() async {
    try {
      final json = await _client.get('/umbrales/mios');
      return Umbral.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.esNoEncontrado) return null;
      rethrow;
    }
  }

  Future<int> guardar(UmbralRequest request) async {
    try {
      final json = await _client.post('/umbrales', body: request.toJson());
      return (json as Map<String, dynamic>)['id'] as int;
    } on NetworkException {
      await _encolar(request);
      return 0;
    } on TimeoutApiException {
      await _encolar(request);
      return 0;
    }
  }

  Future<void> guardarPendiente(UmbralRequest request) => _encolar(request);

  Future<void> sincronizarPendientes() async {
    final pendiente = await _leerUltimoPendiente();
    if (pendiente == null) return;
    try {
      await _client.post('/umbrales', body: pendiente.toJson());
      await _limpiarPendientes();
    } catch (_) {
    }
  }

  Future<void> _encolar(UmbralRequest request) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_clavePendientes, [
        jsonEncode(request.toJson()),
      ]);
    } catch (_) {}
  }

  Future<UmbralRequest?> _leerUltimoPendiente() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pendientes = prefs.getStringList(_clavePendientes);
      if (pendientes == null || pendientes.isEmpty) return null;
      final decoded = jsonDecode(pendientes.last) as Map<String, dynamic>;
      return UmbralRequest.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> _limpiarPendientes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clavePendientes);
    } catch (_) {}
  }
}
