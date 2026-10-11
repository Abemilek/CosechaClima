import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/constants.dart';
import 'paquete_reglas.dart';

/// Fuente única de las reglas en el dispositivo.
///
/// Orden de uso: paquete descargado del servidor (si lo hay) → paquete embebido
/// en la app (assets/reglas/paquete_reglas.json). Así la primera vez que se abre
/// la app, aun sin internet, ya hay catálogos y reglas.
///
/// Las actualizaciones usan GET condicional (If-None-Match con la versión):
/// si nadie editó reglas, el servidor responde 304 sin cuerpo.
class ReglasRepository {
  ReglasRepository._();

  static final ReglasRepository instancia = ReglasRepository._();

  static const _claveCache = 'reglas_paquete_json';
  static const _claveUltimaRevision = 'reglas_ultima_revision';
  static const _asset = 'assets/reglas/paquete_reglas.json';
  static const _intervaloRevision = Duration(hours: 6);

  PaqueteReglas? _actual;

  Future<PaqueteReglas> obtener() async {
    final enMemoria = _actual;
    if (enMemoria != null) return enMemoria;

    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getString(_claveCache);
      if (guardado != null) {
        try {
          return _actual = _parsear(guardado);
        } catch (_) {
          // Copia dañada: se descarta y se usa la embebida.
          await prefs.remove(_claveCache);
        }
      }
    } catch (_) {
      // Sin acceso a preferencias: se usa la embebida.
    }

    return _actual = _parsear(await rootBundle.loadString(_asset));
  }

  /// Revisa el servidor como máximo cada 6 horas. Nunca lanza: si falla, se
  /// sigue con lo que ya hay. Devuelve true si descargó reglas nuevas.
  Future<bool> actualizarSiHaceFalta({bool forzar = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ultima = prefs.getInt(_claveUltimaRevision);
      final ahora = DateTime.now().millisecondsSinceEpoch;
      if (!forzar &&
          ultima != null &&
          ahora - ultima < _intervaloRevision.inMilliseconds) {
        return false;
      }

      final actual = await obtener();
      final respuesta = await http
          .get(
            Uri.parse(
              '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}/reglas/paquete',
            ),
            headers: {'If-None-Match': '"${actual.version}"'},
          )
          .timeout(ApiConfig.timeout);

      // Se anota la revisión aun si no hubo cambios, para no insistir en cada pantalla.
      await prefs.setInt(_claveUltimaRevision, ahora);

      if (respuesta.statusCode != 200) return false;

      final nuevo = _parsear(utf8.decode(respuesta.bodyBytes));
      if (nuevo.version == actual.version) return false;

      await prefs.setString(_claveCache, utf8.decode(respuesta.bodyBytes));
      _actual = nuevo;
      return true;
    } catch (_) {
      return false;
    }
  }

  PaqueteReglas _parsear(String texto) =>
      PaqueteReglas.fromJson(jsonDecode(texto) as Map<String, dynamic>);

  /// Solo para pruebas: reemplaza el paquete en memoria.
  void usarPaqueteParaPruebas(PaqueteReglas? paquete) => _actual = paquete;
}
