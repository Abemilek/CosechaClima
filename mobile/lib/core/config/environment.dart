class Environment {
  Environment._();

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static void validate() {
    if (_envApiUrl.isEmpty) {
      throw Exception(
        'API_URL is required. '
        'Run with: flutter run --dart-define-from-file=.env\n'
        'See mobile/.env.example for setup instructions.',
      );
    }
  }

  static String get apiBaseUrl => _envApiUrl;
}
