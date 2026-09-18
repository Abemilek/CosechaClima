import 'package:geolocator/geolocator.dart';

enum LocationFailureReason {
  servicioDesactivado,
  permisoDenegado,
  permisoDenegadoPermanente,
  desconocido,
}

class LocationException implements Exception {
  final LocationFailureReason reason;
  final String message;

  const LocationException(this.reason, this.message);

  @override
  String toString() => message;
}

class LocationService {
  LocationService._();

  static Future<bool> serviciosActivos() {
    return Geolocator.isLocationServiceEnabled();
  }

  static Future<bool> abrirAjustesUbicacion() {
    return Geolocator.openLocationSettings();
  }

  static Future<bool> abrirAjustesApp() {
    return Geolocator.openAppSettings();
  }

  static Future<LocationPermission> permisoActual() {
    return Geolocator.checkPermission();
  }

  static Future<LocationPermission> solicitarPermiso() {
    return Geolocator.requestPermission();
  }

  static Future<Position> obtenerCoordenadas() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
  }

  static Future<Position> obtenerUbicacionActual() async {
    final servicioActivo = await serviciosActivos();
    if (!servicioActivo) {
      throw const LocationException(
        LocationFailureReason.servicioDesactivado,
        'El GPS del teléfono está desactivado. Activalo en Ajustes e intentá de nuevo.',
      );
    }

    var permiso = await permisoActual();
    if (permiso == LocationPermission.denied) {
      permiso = await solicitarPermiso();
      if (permiso == LocationPermission.denied) {
        throw const LocationException(
          LocationFailureReason.permisoDenegado,
          'Necesitamos tu ubicación para consultar el clima de tu parcela. '
          'Podés ingresarla a mano más abajo.',
        );
      }
    }

    if (permiso == LocationPermission.deniedForever) {
      throw const LocationException(
        LocationFailureReason.permisoDenegadoPermanente,
        'El permiso de ubicación está bloqueado. Activalo desde los '
        'Ajustes del sistema para esta app, o ingresá las coordenadas a mano.',
      );
    }

    try {
      return await obtenerCoordenadas();
    } catch (_) {
      throw const LocationException(
        LocationFailureReason.desconocido,
        'No se pudo obtener tu ubicación. Probá de nuevo en un lugar con mejor señal GPS.',
      );
    }
  }
}
