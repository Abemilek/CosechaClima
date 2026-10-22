/// Error de conectividad al consultar el clima.
class NetworkException implements Exception {
  final String message;

  const NetworkException([
    this.message =
        'No hay conexión a internet. Revisá tu red e intentá de nuevo.',
  ]);

  @override
  String toString() => message;
}

/// El servicio de clima tardó demasiado en responder.
class NetworkTimeoutException implements Exception {
  final String message;

  const NetworkTimeoutException([
    this.message = 'El servicio de clima tardó demasiado. Intentá de nuevo.',
  ]);

  @override
  String toString() => message;
}
