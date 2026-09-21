import 'environment.dart';

class ApiConfig {
  ApiConfig._();

  static String get baseUrl => Environment.apiBaseUrl;

  static const String apiPrefix = '/api';

  static Duration get timeout => const Duration(seconds: 15);
}

class StorageKeys {
  StorageKeys._();

  static const String nombreUsuario = 'auth_nombre';
  static const String emailUsuario = 'auth_email';
  static const String fotoUsuario = 'auth_foto';
}

class SecureStorageKeys {
  SecureStorageKeys._();

  static const String token = 'auth_token';
}
