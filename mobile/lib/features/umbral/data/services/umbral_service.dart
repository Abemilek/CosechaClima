import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/motor/motor_local.dart';
import '../models/umbral.dart';

/// Umbrales del productor guardados en el teléfono.
///
/// Migra automáticamente las claves que usaba la versión con servidor
/// (`umbrales_pendientes` y `umbrales_copia_motor`) para no perder ajustes.
class UmbralService {
  static const clave = 'umbral_local';

  static const _clavePendientesLegado = 'umbrales_pendientes';
  static const _claveCopiaLegado = 'umbrales_copia_motor';

  Future<UmbralConfig> obtener() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo != null && crudo.isNotEmpty) {
        return UmbralConfig.fromJson(jsonDecode(crudo) as Map<String, dynamic>);
      }

      final migrado = _leerLegado(prefs);
      if (migrado != null) {
        await prefs.setString(clave, jsonEncode(migrado.toJson()));
        await prefs.remove(_clavePendientesLegado);
        await prefs.remove(_claveCopiaLegado);
        return migrado;
      }
    } catch (_) {}
    return UmbralConfig.recomendado;
  }

  Future<void> guardar(UmbralConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(clave, jsonEncode(config.toJson()));
    await prefs.remove(_clavePendientesLegado);
    await prefs.remove(_claveCopiaLegado);
  }

  Future<UmbralesMotor> obtenerParaMotor() async => (await obtener()).aMotor();

  UmbralConfig? _leerLegado(SharedPreferences prefs) {
    try {
      final pendientes = prefs.getStringList(_clavePendientesLegado);
      if (pendientes != null && pendientes.isNotEmpty) {
        return UmbralConfig.fromJson(
          jsonDecode(pendientes.last) as Map<String, dynamic>,
        );
      }
    } catch (_) {}

    try {
      final crudo = prefs.getString(_claveCopiaLegado);
      if (crudo == null || crudo.isEmpty) return null;
      final json = jsonDecode(crudo) as Map<String, dynamic>;
      return UmbralConfig(
        lluviaIntensaMm: (json['lluvia'] as num?)?.toInt() ?? 100,
        vientoFuerteKmh: (json['viento'] as num?)?.toInt() ?? 40,
        caniculaDias: (json['canicula'] as num?)?.toInt() ?? 7,
      );
    } catch (_) {
      return null;
    }
  }
}
