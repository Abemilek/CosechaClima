class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  bool get esNoEncontrado => statusCode == 404;

  bool get esNoAutorizado => statusCode == 401;

  bool get esProhibido => statusCode == 403;

  bool get esDemasiadasPeticiones => statusCode == 429;

  bool get esErrorDeServidor => statusCode >= 500;

  @override
  String toString() => message;
}

class NetworkException implements Exception {
  final String message;

  const NetworkException([
    this.message = 'No se pudo conectar con el servidor. Revisá tu conexión.',
  ]);

  @override
  String toString() => message;
}

class TimeoutApiException implements Exception {
  final String message;

  const TimeoutApiException([
    this.message = 'El servidor tardó demasiado en responder. Intentá de nuevo.',
  ]);

  @override
  String toString() => message;
}