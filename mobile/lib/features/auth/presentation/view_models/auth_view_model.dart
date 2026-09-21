import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/security/jwt_decoder.dart';
import '../../data/services/auth_service.dart';

enum EstadoSesion { desconocido, autenticado, invitado }

class AuthViewModel extends ChangeNotifier {
  final AuthService _authService;

  AuthViewModel(this._authService) {
    _revisarSesionGuardada();
  }

  EstadoSesion _estado = EstadoSesion.desconocido;
  String? _nombre;
  String? _fotoUrl;
  bool _esAdmin = false;
  bool _cargando = false;
  String? _error;
  bool _onboardingVisto = false;

  static const _claveOnboarding = 'onboarding_visto';

  EstadoSesion get estado => _estado;
  String? get nombre => _nombre;
  String? get fotoUrl => _fotoUrl;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get esAdmin => _esAdmin;

  bool get estaAutenticado => _estado == EstadoSesion.autenticado;

  bool get onboardingVisto => _onboardingVisto;

  Future<void> marcarOnboardingVisto() async {
    if (_onboardingVisto) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_claveOnboarding, true);
    _onboardingVisto = true;
    notifyListeners();
  }

  Future<void> _revisarSesionGuardada() async {
    final prefs = await SharedPreferences.getInstance();
    _onboardingVisto = prefs.getBool(_claveOnboarding) ?? false;

    final activa = await _authService.haySesionActiva();
    _nombre = await _authService.nombreGuardado();
    _fotoUrl = await _authService.fotoGuardada();
    _esAdmin = await _detectarRolAdmin();
    _estado = activa ? EstadoSesion.autenticado : EstadoSesion.invitado;
    notifyListeners();
  }

  Future<bool> _detectarRolAdmin() async {
    final token = await _authService.tokenActual();
    if (token == null) return false;
    return JwtDecoder.esAdmin(token);
  }

  Future<bool> loginConGoogle() => _ejecutar(() async {
    final resp = await _authService.loginConGoogle();
    if (resp == null) return false; // canceló

    _nombre = resp.nombre;
    _fotoUrl = resp.fotoUrl;
    _esAdmin = JwtDecoder.esAdmin(resp.token);
    _estado = EstadoSesion.autenticado;
    return true;
  });

  Future<bool> registrarConEmail({
    required String nombre,
    required String email,
    required String password,
  }) => _ejecutar(() async {
    final resp = await _authService.registrarConEmail(
      nombre: nombre,
      email: email,
      password: password,
    );
    _aplicarSesion(resp.nombre, resp.fotoUrl, resp.token);
    return true;
  });

  Future<bool> loginConEmail({
    required String email,
    required String password,
  }) => _ejecutar(() async {
    final resp = await _authService.loginConEmail(
      email: email,
      password: password,
    );
    _aplicarSesion(resp.nombre, resp.fotoUrl, resp.token);
    return true;
  });

  void _aplicarSesion(String nombre, String? fotoUrl, String token) {
    _nombre = nombre;
    _fotoUrl = fotoUrl;
    _esAdmin = JwtDecoder.esAdmin(token);
    _estado = EstadoSesion.autenticado;
  }

  Future<void> cerrarSesion() async {
    await _authService.cerrarSesion();
    _nombre = null;
    _fotoUrl = null;
    _esAdmin = false;
    _estado = EstadoSesion.invitado;
    notifyListeners();
  }

  void limpiarError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<bool> _ejecutar(Future<bool> Function() accion) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      return await accion();
    } on ApiException catch (e) {
      _error = e.message;
      return false;
    } on NetworkException catch (e) {
      _error = e.message;
      return false;
    } on TimeoutApiException catch (e) {
      _error = e.message;
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
