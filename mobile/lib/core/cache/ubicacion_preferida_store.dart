import 'package:shared_preferences/shared_preferences.dart';

class UbicacionPreferidaStore {
  static const _clave = 'ubicacion_preferida_municipio';

  Future<String?> obtener() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final valor = prefs.getString(_clave);
      if (valor == null || valor.trim().isEmpty) return null;
      return valor;
    } catch (_) {
      return null;
    }
  }

  Future<void> guardar(String municipio) async {
    if (municipio.trim().isEmpty) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_clave, municipio);
    } catch (_) {}
  }
}
