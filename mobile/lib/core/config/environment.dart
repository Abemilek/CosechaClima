class Environment {
  Environment._();

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');

  static const String _envApiUrl = String.fromEnvironment('API_URL');

  static const String _envGoogleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
  );

  static void validate() {
    if (_envApiUrl.trim().isEmpty) {
      throw Exception(
        'API_URL is required. '
        'Run with: flutter run --dart-define-from-file=.env\n'
        'See mobile/.env.example for setup instructions.',
      );
    }
  }

  static String get apiBaseUrl =>
      _envApiUrl.trim().replaceFirst(RegExp(r'/+$'), '');

  static String? get googleServerClientId =>
      _envGoogleServerClientId.trim().isEmpty
      ? null
      : _envGoogleServerClientId.trim();

  static bool get googleSignInDisponible => googleServerClientId != null;
}
