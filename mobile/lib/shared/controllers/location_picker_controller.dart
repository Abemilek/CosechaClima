import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/services/location_service.dart';

enum LocationPickerStatus {
  idle,
  checkingHardware,
  openingLocationSettings,
  requestingPermission,
  permissionDenied,
  permissionDeniedForever,
  locating,
  success,
  error,
}

class LocationPickerController extends ChangeNotifier {
  final TextEditingController latitudCtrl;
  final TextEditingController longitudCtrl;
  final VoidCallback onChanged;

  LocationPickerController({
    required this.latitudCtrl,
    required this.longitudCtrl,
    required this.onChanged,
  }) {
    mostrarManual = tieneCoordenadas;
    if (tieneCoordenadas) {
      status = LocationPickerStatus.success;
      message = 'Ubicación detectada.';
    }
  }

  LocationPickerStatus status = LocationPickerStatus.idle;
  String? message;
  bool mostrarManual = false;

  bool get tieneCoordenadas =>
      latitudCtrl.text.trim().isNotEmpty && longitudCtrl.text.trim().isNotEmpty;

  bool get estaTrabajando =>
      status == LocationPickerStatus.checkingHardware ||
      status == LocationPickerStatus.openingLocationSettings ||
      status == LocationPickerStatus.requestingPermission ||
      status == LocationPickerStatus.locating;

  bool get requiereAjustesApp =>
      status == LocationPickerStatus.permissionDeniedForever;

  bool get requiereAjustesGps =>
      status == LocationPickerStatus.openingLocationSettings;

  void cambiarManualVisible() {
    mostrarManual = !mostrarManual;
    if (mostrarManual && !tieneCoordenadas) {
      status = LocationPickerStatus.idle;
      message =
          'Podés continuar con municipio y comunidad. Si después agregás '
          'coordenadas, el clima será más preciso.';
    }
    notifyListeners();
  }

  void notificarCambioManual() {
    if (tieneCoordenadas) {
      status = LocationPickerStatus.success;
      message = 'Ubicación lista para consultar el clima.';
    } else if (status == LocationPickerStatus.success) {
      status = LocationPickerStatus.idle;
      message = null;
    }
    onChanged();
    notifyListeners();
  }

  Future<void> continuarConGps() async {
    if (estaTrabajando) return;

    status = LocationPickerStatus.checkingHardware;
    message = 'Revisando si el GPS del teléfono está encendido...';
    notifyListeners();

    final servicioActivo = await LocationService.serviciosActivos();
    if (!servicioActivo) {
      status = LocationPickerStatus.openingLocationSettings;
      message =
          'El GPS está apagado. Te llevamos a Ajustes para encenderlo. '
          'Al volver, tocá "Detectar mi ubicación" otra vez.';
      mostrarManual = true;
      notifyListeners();
      await LocationService.abrirAjustesUbicacion();
      return;
    }

    status = LocationPickerStatus.requestingPermission;
    message = 'Esperando permiso de ubicación del teléfono...';
    notifyListeners();

    var permiso = await LocationService.permisoActual();
    if (permiso == LocationPermission.denied) {
      permiso = await LocationService.solicitarPermiso();
    }

    if (permiso == LocationPermission.denied) {
      status = LocationPickerStatus.permissionDenied;
      message =
          'No se concedió el permiso. Podés intentar de nuevo o ingresar '
          'la ubicación manualmente.';
      mostrarManual = true;
      notifyListeners();
      return;
    }

    if (permiso == LocationPermission.deniedForever) {
      status = LocationPickerStatus.permissionDeniedForever;
      message =
          'El permiso quedó bloqueado para esta app. Abrí los ajustes de '
          'la app y habilitá ubicación, o ingresá el municipio manualmente.';
      mostrarManual = true;
      notifyListeners();
      return;
    }

    await _obtenerCoordenadas();
  }

  Future<void> abrirAjustesApp() async {
    await LocationService.abrirAjustesApp();
  }

  Future<void> abrirAjustesGps() async {
    status = LocationPickerStatus.openingLocationSettings;
    message =
        'Abrí los ajustes de ubicación, encendé el GPS y regresá a la app.';
    mostrarManual = true;
    notifyListeners();
    await LocationService.abrirAjustesUbicacion();
  }

  Future<void> _obtenerCoordenadas() async {
    status = LocationPickerStatus.locating;
    message = 'Detectando ubicación...';
    notifyListeners();

    try {
      final posicion = await LocationService.obtenerCoordenadas();
      latitudCtrl.text = posicion.latitude.toStringAsFixed(6);
      longitudCtrl.text = posicion.longitude.toStringAsFixed(6);
      status = LocationPickerStatus.success;
      message = 'Ubicación detectada correctamente.';
      mostrarManual = false;
      onChanged();
      notifyListeners();
    } catch (_) {
      status = LocationPickerStatus.error;
      message =
          'No se pudo obtener la ubicación. Probá en un lugar con mejor '
          'señal GPS o ingresá el municipio manualmente.';
      mostrarManual = true;
      notifyListeners();
    }
  }
}
