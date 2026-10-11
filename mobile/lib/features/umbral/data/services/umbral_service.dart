import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/motor/motor_local.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/umbral.dart';

class UmbralService {
  final ApiClient _client;

  UmbralService(this._client);

  static const _clavePendientes = 'umbrales_pendientes';
  static const _claveCopia = 'umbrales_copia_motor';

  Future<Umbral?> obtenerMios() async {
    try {
      final json = await _client.get('/umbrales/mios');
      return Umbral.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.esNoEncontrado) return null;
      rethrow;
    }
  }

  /// Umbrales que usa el motor en el dispositivo. Orden de prioridad:
  /// 1) cambios que el productor hizo sin conexión y aún no se sincronizan,
  /// 2) lo que dice el servidor (y se guarda una copia),
  /// 3) la última copia guardada,
  /// 4) valores por defecto (igual que el servidor cuando no hay configuración).
  Future<UmbralesMotor> obtenerParaMotor() async {
    final pendiente = await _leerUltimoPendiente();
    if (pendiente != null) {
      return UmbralesMotor(
        lluviaIntensaMm: pendiente.lluviaIntensaMm,
        vientoFuerteKmh: pendiente.vientoFuerteKmh,
        caniculaDias: pendiente.caniculaDias,
      );
    }

    try {
      final umbral = await obtenerMios();
      if (umbral == null) return const UmbralesMotor();
      final motor = UmbralesMotor(
        lluviaIntensaMm: umbral.lluviaIntensaMm,
        vientoFuerteKmh: umbral.vientoFuerteKmh,
        caniculaDias: umbral.caniculaDias,
      );
      await _guardarCopia(motor);
      return motor;
    } on NetworkException {
      return await _leerCopia() ?? const UmbralesMotor();
    } on TimeoutApiException {
      return await _leerCopia() ?? const UmbralesMotor();
    } on ApiException catch (e) {
      if (e.esErrorDeServidor) {
        return await _leerCopia() ?? const UmbralesMotor();
      }
      rethrow;
    }
  }

  Future<void> _guardarCopia(UmbralesMotor u) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _claveCopia,
        jsonEncode({
          'lluvia': u.lluviaIntensaMm,
          'viento': u.vientoFuerteKmh,
          'canicula': u.caniculaDias,
        }),
      );
    } catch (_) {}
  }

  Future<UmbralesMotor?> _leerCopia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveCopia);
      if (crudo == null) return null;
      final json = jsonDecode(crudo) as Map<String, dynamic>;
      return UmbralesMotor(
        lluviaIntensaMm: json['lluvia'] as int,
        vientoFuerteKmh: json['viento'] as int,
        caniculaDias: json['canicula'] as int,
      );
    } catch (_) {
      return null;
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
    } catch (_) {}
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
