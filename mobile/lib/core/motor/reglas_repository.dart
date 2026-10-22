import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'paquete_reglas.dart';

/// Fuente única de catálogos y reglas en el dispositivo.
///
/// La app es local-first: usa el paquete embebido en
/// `assets/reglas/paquete_reglas.json`. No descarga reglas ni depende de un
/// servidor. Al actualizar la app se actualizan también sus reglas.
class ReglasRepository {
  ReglasRepository._();

  static final ReglasRepository instancia = ReglasRepository._();

  static const _asset = 'assets/reglas/paquete_reglas.json';

  PaqueteReglas? _actual;

  Future<PaqueteReglas> obtener() async {
    final enMemoria = _actual;
    if (enMemoria != null) return enMemoria;
    return _actual = _parsear(await rootBundle.loadString(_asset));
  }

  PaqueteReglas _parsear(String texto) =>
      PaqueteReglas.fromJson(jsonDecode(texto) as Map<String, dynamic>);
}
