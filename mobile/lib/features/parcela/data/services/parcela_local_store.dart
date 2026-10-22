import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/parcela_local.dart';

/// Almacén de parcelas 100 % local.
///
/// Se conserva la clave histórica `parcelas_invitado` para no perder las
/// parcelas que los usuarios ya habían creado en el modo sin cuenta.
class ParcelaLocalStore {
  static const clave = 'parcelas_invitado';

  Future<List<ParcelaLocal>> listar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(clave);
      if (crudo == null || crudo.isEmpty) return [];
      final lista = jsonDecode(crudo) as List<dynamic>;
      final parcelas = <ParcelaLocal>[];
      for (final item in lista) {
        try {
          parcelas.add(
            ParcelaLocal.fromJson(Map<String, dynamic>.from(item as Map)),
          );
        } catch (_) {
          // Una entrada dañada no debe ocultar las demás parcelas.
        }
      }
      parcelas.sort((a, b) => b.actualizadaEn.compareTo(a.actualizadaEn));
      return parcelas;
    } catch (_) {
      return [];
    }
  }

  Future<ParcelaLocal?> obtener(String id) async {
    final parcelas = await listar();
    for (final parcela in parcelas) {
      if (parcela.id == id) return parcela;
    }
    return null;
  }

  Future<ParcelaLocal> agregar({
    required int cultivoId,
    required String cultivoNombre,
    required int tipoSueloId,
    required String tipoSueloNombre,
    int? etapaFenologicaId,
    required double latitud,
    required double longitud,
    String? municipio,
    String? comunidad,
    required DateTime fechaSiembra,
    required double areaMzs,
  }) async {
    final ahora = DateTime.now();
    final nueva = ParcelaLocal(
      id: 'p_${ahora.microsecondsSinceEpoch}',
      cultivoId: cultivoId,
      cultivoNombre: cultivoNombre,
      tipoSueloId: tipoSueloId,
      tipoSueloNombre: tipoSueloNombre,
      etapaFenologicaId: etapaFenologicaId,
      latitud: latitud,
      longitud: longitud,
      municipio: municipio,
      comunidad: comunidad,
      fechaSiembra: fechaSiembra,
      areaMzs: areaMzs,
      creadaEn: ahora,
      actualizadaEn: ahora,
    );

    final actuales = await listar();
    actuales.add(nueva);
    await _guardarTodas(actuales);
    return nueva;
  }

  Future<void> actualizar(ParcelaLocal parcela) async {
    final actuales = await listar();
    final indice = actuales.indexWhere((p) => p.id == parcela.id);
    if (indice == -1) {
      throw StateError('La parcela ya no existe en este teléfono.');
    }
    actuales[indice] = parcela;
    await _guardarTodas(actuales);
  }

  Future<void> eliminar(String id) async {
    final actuales = await listar();
    actuales.removeWhere((p) => p.id == id);
    await _guardarTodas(actuales);
  }

  Future<void> limpiarTodas() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(clave);
  }

  Future<void> reemplazarTodas(List<ParcelaLocal> parcelas) =>
      _guardarTodas(parcelas);

  Future<void> _guardarTodas(List<ParcelaLocal> parcelas) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      clave,
      jsonEncode(parcelas.map((p) => p.toJson()).toList()),
    );
  }
}
