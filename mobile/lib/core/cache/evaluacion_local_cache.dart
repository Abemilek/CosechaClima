import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/clima/data/models/clima.dart';

class EvaluacionLocalGuardada {
  final DatosClimaticos clima;
  final Semaforo semaforo;
  final ResumenSemanal resumen;
  final DateTime guardadoEn;

  const EvaluacionLocalGuardada({
    required this.clima,
    required this.semaforo,
    required this.resumen,
    required this.guardadoEn,
  });
}

/// Último cálculo completo de una parcela local.
///
/// El motor y la caché de Open-Meteo ya permiten trabajar sin conexión. Esta
/// copia es el último respaldo: sirve para mostrar el semáforo y el plan aunque
/// el pronóstico guardado haya vencido.
class EvaluacionLocalCache {
  static String _clave(String parcelaId) => 'evaluacion_local_$parcelaId';

  Future<void> guardar({
    required String parcelaId,
    required DatosClimaticos clima,
    required Semaforo semaforo,
    required ResumenSemanal resumen,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave(parcelaId),
        jsonEncode({
          'clima': clima.toJson(),
          'semaforo': semaforo.toJson(),
          'resumen': resumen.toJson(),
          'guardadoEn': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<EvaluacionLocalGuardada?> obtener(String parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave(parcelaId));
      if (crudo == null || crudo.isEmpty) return null;

      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final clima = data['clima'] as Map<String, dynamic>?;
      final semaforo = data['semaforo'] as Map<String, dynamic>?;
      final resumen = data['resumen'] as Map<String, dynamic>?;
      final guardadoEn = DateTime.tryParse(data['guardadoEn'] as String? ?? '');
      if (clima == null ||
          semaforo == null ||
          resumen == null ||
          guardadoEn == null) {
        return null;
      }

      return EvaluacionLocalGuardada(
        clima: DatosClimaticos.fromJson(clima),
        semaforo: Semaforo.fromJson(semaforo),
        resumen: ResumenSemanal.fromJson(resumen),
        guardadoEn: guardadoEn,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar(String parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave(parcelaId));
    } catch (_) {}
  }

  Future<void> limpiarTodas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final claves = prefs.getKeys().where(
        (clave) => clave.startsWith('evaluacion_local_'),
      );
      for (final clave in claves) {
        await prefs.remove(clave);
      }
    } catch (_) {}
  }
}
