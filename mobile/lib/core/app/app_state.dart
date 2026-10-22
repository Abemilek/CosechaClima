import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Estado global mínimo de la app local.
///
/// No hay sesión ni cuentas: solo recordamos si el tutorial ya se vio.
class AppState extends ChangeNotifier {
  AppState() {
    _cargar();
  }

  static const _claveOnboarding = 'onboarding_visto';

  bool _cargando = true;
  bool _onboardingVisto = false;

  bool get cargando => _cargando;
  bool get onboardingVisto => _onboardingVisto;

  Future<void> _cargar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _onboardingVisto = prefs.getBool(_claveOnboarding) ?? false;
    } catch (_) {
      _onboardingVisto = false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  Future<void> marcarOnboardingVisto() async {
    if (_onboardingVisto) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_claveOnboarding, true);
    } catch (_) {}
    _onboardingVisto = true;
    notifyListeners();
  }
}
