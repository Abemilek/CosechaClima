import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../features/clima/data/models/clima.dart';
import '../../features/parcela/data/models/parcela.dart';

class CachedParcelas {
  final List<Parcela> parcelas;
  final DateTime guardadoEn;

  const CachedParcelas({required this.parcelas, required this.guardadoEn});
}

class CachedParcelaClima {
  final DatosClimaticos clima;
  final Semaforo semaforo;
  final ResumenSemanal? resumenSemanal;
  final DateTime guardadoEn;

  const CachedParcelaClima({
    required this.clima,
    required this.semaforo,
    this.resumenSemanal,
    required this.guardadoEn,
  });
}

class CachedResumenLocal {
  final ResumenSemanal resumen;
  final DateTime guardadoEn;

  const CachedResumenLocal({required this.resumen, required this.guardadoEn});
}

class ParcelaCache {
  static String _key(int parcelaId) => 'cache_clima_parcela_$parcelaId';

  Future<void> guardar({
    required int parcelaId,
    required DatosClimaticos clima,
    required Semaforo semaforo,
    ResumenSemanal? resumenSemanal,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'clima': clima.toJson(),
        'semaforo': semaforo.toJson(),
        if (resumenSemanal != null) 'resumenSemanal': resumenSemanal.toJson(),
        'guardadoEn': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_key(parcelaId), payload);
    } catch (_) {}
  }

  Future<CachedParcelaClima?> obtener(int parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_key(parcelaId));
      if (crudo == null || crudo.isEmpty) return null;

      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final climaJson = data['clima'] as Map<String, dynamic>?;
      final semaforoJson = data['semaforo'] as Map<String, dynamic>?;
      final resumenJson = data['resumenSemanal'] as Map<String, dynamic>?;
      final guardadoEnCrudo = data['guardadoEn'] as String?;

      if (climaJson == null ||
          semaforoJson == null ||
          guardadoEnCrudo == null) {
        return null;
      }

      return CachedParcelaClima(
        clima: DatosClimaticos.fromJson(climaJson),
        semaforo: Semaforo.fromJson(semaforoJson),
        resumenSemanal: resumenJson == null
            ? null
            : ResumenSemanal.fromJson(resumenJson),
        guardadoEn: DateTime.parse(guardadoEnCrudo),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiar(int parcelaId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key(parcelaId));
    } catch (_) {}
  }

  // --- Plan semanal de una parcela local (invitado o pendiente de subir) ---
  static String _keyResumenLocal(String idLocal) =>
      'cache_resumen_local_$idLocal';

  Future<void> guardarResumenLocal({
    required String idLocal,
    required ResumenSemanal resumen,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _keyResumenLocal(idLocal),
        jsonEncode({
          'resumen': resumen.toJson(),
          'guardadoEn': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {}
  }

  Future<CachedResumenLocal?> obtenerResumenLocal(String idLocal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_keyResumenLocal(idLocal));
      if (crudo == null || crudo.isEmpty) return null;

      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final resumenJson = data['resumen'] as Map<String, dynamic>?;
      final guardadoEnCrudo = data['guardadoEn'] as String?;
      if (resumenJson == null || guardadoEnCrudo == null) return null;

      return CachedResumenLocal(
        resumen: ResumenSemanal.fromJson(resumenJson),
        guardadoEn: DateTime.parse(guardadoEnCrudo),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> limpiarResumenLocal(String idLocal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyResumenLocal(idLocal));
    } catch (_) {}
  }

  // --- Cache de la lista de parcelas (para funcionar sin servidor/internet) ---
  static const _claveListaParcelas = 'cache_lista_parcelas';

  Future<void> guardarLista(List<Parcela> parcelas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = jsonEncode({
        'parcelas': parcelas.map((p) => p.toJson()).toList(),
        'guardadoEn': DateTime.now().toIso8601String(),
      });
      await prefs.setString(_claveListaParcelas, payload);
    } catch (_) {}
  }

  Future<CachedParcelas?> obtenerLista() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_claveListaParcelas);
      if (crudo == null || crudo.isEmpty) return null;

      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final listaJson = data['parcelas'] as List<dynamic>?;
      final guardadoEnCrudo = data['guardadoEn'] as String?;
      if (listaJson == null || guardadoEnCrudo == null) return null;

      return CachedParcelas(
        parcelas: listaJson
            .map((e) => Parcela.fromJson(e as Map<String, dynamic>))
            .toList(),
        guardadoEn: DateTime.parse(guardadoEnCrudo),
      );
    } catch (_) {
      return null;
    }
  }
}
