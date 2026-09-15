class Environment {
  Environment._();

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static String? _autoResolved;

  static Future<void> initialize() async {
    if (_envApiUrl.isNotEmpty) return;

    if (isProduction && _envApiUrl.isEmpty) {
      throw Exception(
        'API_URL must be provided in production builds via --dart-define',
      );
    }

    _autoResolved = 'http://localhost:5005';
  }

  static String get apiBaseUrl {
    if (_envApiUrl.isNotEmpty) {
      return _envApiUrl;
    }

    return _autoResolved ?? 'http://localhost:5005';
  }
}
