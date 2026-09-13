import 'package:flutter/foundation.dart';

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
  bool _esAdmin = false;
  bool _cargando = false;
  String? _error;

  EstadoSesion get estado => _estado;
  String? get nombre => _nombre;
  bool get cargando => _cargando;
  String? get error => _error;

  bool get esAdmin => _esAdmin;

  Future<void> _revisarSesionGuardada() async {
    final activa = await _authService.haySesionActiva();
    _nombre = await _authService.nombreGuardado();
    _esAdmin = await _detectarRolAdmin();
    _estado = activa ? EstadoSesion.autenticado : EstadoSesion.invitado;
    notifyListeners();
  }

  Future<bool> _detectarRolAdmin() async {
    final token = await _authService.tokenActual();
    if (token == null) return false;
    return JwtDecoder.esAdmin(token);
  }

  Future<bool> registrar({
    required String nombre,
    required String telefono,
    required String pin,
  }) => _ejecutar(
    () => _authService.registrar(nombre: nombre, telefono: telefono, pin: pin),
  );

  Future<bool> login({required String telefono, required String pin}) =>
      _ejecutar(() async {
        final resp = await _authService.login(telefono: telefono, pin: pin);
        _nombre = resp.nombre;
        _esAdmin = JwtDecoder.esAdmin(resp.token);
        _estado = EstadoSesion.autenticado;
      });

  Future<void> cerrarSesion() async {
    await _authService.cerrarSesion();
    _nombre = null;
    _esAdmin = false;
    _estado = EstadoSesion.invitado;
    notifyListeners();
  }

  Future<bool> _ejecutar(Future<void> Function() accion) async {
    _cargando = true;
    _error = null;
    notifyListeners();
    try {
      await accion();
      return true;
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
