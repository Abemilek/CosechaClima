import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/security/secure_storage.dart';
import '../models/usuario.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  Future<void> registrar({
    required String nombre,
    required String telefono,
    required String pin,
  }) async {
    await _client.post(
      '/auth/register',
      auth: false,
      body: {'nombre': nombre, 'telefono': telefono, 'pin': pin},
    );
  }

  Future<LoginResponse> login({
    required String telefono,
    required String pin,
  }) async {
    final json = await _client.post(
      '/auth/login',
      auth: false,
      body: {'telefono': telefono, 'pin': pin},
    );
    final response = LoginResponse.fromJson(json as Map<String, dynamic>);
    await _guardarSesion(response);
    return response;
  }

  Future<void> _guardarSesion(LoginResponse response) async {
    await SecureStorage.write(SecureStorageKeys.token, response.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.nombreUsuario, response.nombre);
  }

  Future<void> cerrarSesion() async {
    await SecureStorage.delete(SecureStorageKeys.token);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.nombreUsuario);
  }

  Future<bool> haySesionActiva() async {
    final token = await SecureStorage.read(SecureStorageKeys.token);
    return token != null && token.isNotEmpty;
  }

  Future<String?> tokenActual() => SecureStorage.read(SecureStorageKeys.token);

  Future<String?> nombreGuardado() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.nombreUsuario);
  }
}
