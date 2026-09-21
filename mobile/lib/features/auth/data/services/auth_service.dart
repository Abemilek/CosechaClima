import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/constants.dart';
import '../../../../core/config/environment.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/security/secure_storage.dart';
import '../models/usuario.dart';

class AuthService {
  final ApiClient _client;

  AuthService(this._client);

  GoogleSignIn _construirGoogleSignIn() => GoogleSignIn(
    scopes: const ['email', 'profile'],
    serverClientId: Environment.googleServerClientId,
  );

  Future<LoginResponse?> loginConGoogle() async {
    final googleSignIn = _construirGoogleSignIn();

    await googleSignIn.signOut();

    final cuenta = await googleSignIn.signIn();
    if (cuenta == null) return null;

    final autenticacion = await cuenta.authentication;
    final idToken = autenticacion.idToken;

    if (idToken == null || idToken.isEmpty) {
      throw ApiException(
        0,
        'Google no devolvió un token de identidad. Revisá que el '
        'serverClientId (Client ID de tipo Web) esté configurado.',
      );
    }

    final json = await _client.post(
      '/auth/google',
      auth: false,
      body: {'idToken': idToken},
    );

    final response = LoginResponse.fromJson(json as Map<String, dynamic>);
    await _guardarSesion(response);
    return response;
  }

  Future<LoginResponse> registrarConEmail({
    required String nombre,
    required String email,
    required String password,
  }) async {
    final json = await _client.post(
      '/auth/register',
      auth: false,
      body: {'nombre': nombre, 'email': email, 'password': password},
    );

    final response = LoginResponse.fromJson(json as Map<String, dynamic>);
    await _guardarSesion(response);
    return response;
  }

  Future<LoginResponse> loginConEmail({
    required String email,
    required String password,
  }) async {
    final json = await _client.post(
      '/auth/login',
      auth: false,
      body: {'email': email, 'password': password},
    );

    final response = LoginResponse.fromJson(json as Map<String, dynamic>);
    await _guardarSesion(response);
    return response;
  }

  Future<void> _guardarSesion(LoginResponse response) async {
    await SecureStorage.write(SecureStorageKeys.token, response.token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(StorageKeys.nombreUsuario, response.nombre);
    await prefs.setString(StorageKeys.emailUsuario, response.email);
    if (response.fotoUrl != null) {
      await prefs.setString(StorageKeys.fotoUsuario, response.fotoUrl!);
    } else {
      await prefs.remove(StorageKeys.fotoUsuario);
    }
  }

  Future<void> cerrarSesion() async {
    try {
      await _construirGoogleSignIn().signOut();
    } catch (_) {
    }

    await SecureStorage.delete(SecureStorageKeys.token);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(StorageKeys.nombreUsuario);
    await prefs.remove(StorageKeys.emailUsuario);
    await prefs.remove(StorageKeys.fotoUsuario);
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

  Future<String?> fotoGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(StorageKeys.fotoUsuario);
  }
}
