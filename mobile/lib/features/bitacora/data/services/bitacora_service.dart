import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/bitacora.dart';

/// Cuaderno de campo 100 % local.
///
/// Cada parcela guarda sus entradas en el teléfono. No hay sincronización ni
/// servidor: la información viaja en la copia de seguridad JSON.
class BitacoraService {
  static const clave = 'bitacora_local_v1';

  Future<List<BitacoraEntry>> obtenerTodas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null || crudo.isEmpty) return [];
      final lista = jsonDecode(crudo) as List<dynamic>;
      return lista
          .map((e) => BitacoraEntry.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.fecha.compareTo(a.fecha));
    } catch (_) {
      return [];
    }
  }

  Future<List<BitacoraEntry>> obtenerDeParcela(String parcelaId) async {
    final todas = await obtenerTodas();
    return todas.where((e) => e.parcelaId == parcelaId).toList();
  }

  Future<BitacoraEntry> crear(BitacoraRequest request) async {
    final ahora = DateTime.now();
    final entrada = BitacoraEntry(
      id: 'b_${ahora.microsecondsSinceEpoch}',
      parcelaId: request.parcelaId,
      fecha: request.fecha,
      eventoClimaticoId: request.eventoClimaticoId,
      nivelRiesgo: request.nivelRiesgo,
      accion1Texto: request.accion1Texto,
      accion2Texto: request.accion2Texto,
      accion3Texto: request.accion3Texto,
      accion1Completada: false,
      accion2Completada: false,
      accion3Completada: false,
      notas: request.notas,
    );

    final todas = await obtenerTodas();
    todas.add(entrada);
    await _guardarTodas(todas);
    return entrada;
  }

  Future<void> marcarAccion(String entradaId, int numeroAccion) async {
    assert(numeroAccion >= 1 && numeroAccion <= 3);
    final todas = await obtenerTodas();
    final indice = todas.indexWhere((e) => e.id == entradaId);
    if (indice == -1) return;

    final entrada = todas[indice];
    todas[indice] = switch (numeroAccion) {
      1 => entrada.copyWith(accion1Completada: true),
      2 => entrada.copyWith(accion2Completada: true),
      3 => entrada.copyWith(accion3Completada: true),
      _ => entrada,
    };
    await _guardarTodas(todas);
  }

  Future<void> eliminarEntrada(String entradaId) async {
    final todas = await obtenerTodas();
    todas.removeWhere((e) => e.id == entradaId);
    await _guardarTodas(todas);
  }

  Future<void> eliminarDeParcela(String parcelaId) async {
    final todas = await obtenerTodas();
    todas.removeWhere((e) => e.parcelaId == parcelaId);
    await _guardarTodas(todas);
  }

  Future<String> obtenerResumen({String? parcelaId}) async {
    final entradas = parcelaId == null
        ? await obtenerTodas()
        : await obtenerDeParcela(parcelaId);
    if (entradas.isEmpty) {
      return 'Todavía no hay registros en la bitácora.';
    }

    final completadas = entradas.fold<int>(0, (total, entrada) {
      var suma = total;
      for (var i = 1; i <= 3; i++) {
        if (entrada.completada(i)) suma++;
      }
      return suma;
    });
    final riesgos = entradas.map((e) => e.nivelRiesgo.toLowerCase()).toSet();
    final nivel = riesgos.contains('alto')
        ? 'Alto'
        : riesgos.contains('medio')
        ? 'Medio'
        : 'Bajo';

    return 'CosechaClima · Mi cuaderno de campo\n'
        'Registros: ${entradas.length}\n'
        'Acciones completadas: $completadas\n'
        'Riesgo máximo registrado: $nivel\n'
        'Último registro: ${_fecha(entradas.first.fecha)}';
  }

  Future<void> reemplazarTodas(List<BitacoraEntry> entradas) =>
      _guardarTodas(entradas);

  Future<void> _guardarTodas(List<BitacoraEntry> entradas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      clave,
      jsonEncode(entradas.map((e) => e.toJson()).toList()),
    );
  }

  static String _fecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    return '$dia/$mes/${fecha.year}';
  }
}
