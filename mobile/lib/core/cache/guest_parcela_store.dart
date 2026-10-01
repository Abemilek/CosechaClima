import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class GuestParcela {
  final String idLocal;
  final int cultivoId;
  final String cultivoNombre;
  final int tipoSueloId;
  final String tipoSueloNombre;
  final int? etapaFenologicaId;
  final double latitud;
  final double longitud;
  final String? municipio;
  final String? comunidad;
  final DateTime fechaSiembra;
  final double areaMzs;
  final DateTime creadaEn;

  GuestParcela({
    required this.idLocal,
    required this.cultivoId,
    required this.cultivoNombre,
    required this.tipoSueloId,
    required this.tipoSueloNombre,
    this.etapaFenologicaId,
    required this.latitud,
    required this.longitud,
    this.municipio,
    this.comunidad,
    required this.fechaSiembra,
    required this.areaMzs,
    required this.creadaEn,
  });

  Map<String, dynamic> toJson() => {
    'idLocal': idLocal,
    'cultivoId': cultivoId,
    'cultivoNombre': cultivoNombre,
    'tipoSueloId': tipoSueloId,
    'tipoSueloNombre': tipoSueloNombre,
    'etapaFenologicaId': etapaFenologicaId,
    'latitud': latitud,
    'longitud': longitud,
    'municipio': municipio,
    'comunidad': comunidad,
    'fechaSiembra': fechaSiembra.toIso8601String(),
    'areaMzs': areaMzs,
    'creadaEn': creadaEn.toIso8601String(),
  };

  factory GuestParcela.fromJson(Map<String, dynamic> json) => GuestParcela(
    idLocal: json['idLocal'] as String,
    cultivoId: json['cultivoId'] as int,
    cultivoNombre: json['cultivoNombre'] as String,
    tipoSueloId: json['tipoSueloId'] as int,
    tipoSueloNombre: json['tipoSueloNombre'] as String,
    etapaFenologicaId: json['etapaFenologicaId'] as int?,
    latitud: (json['latitud'] as num).toDouble(),
    longitud: (json['longitud'] as num).toDouble(),
    municipio: json['municipio'] as String?,
    comunidad: json['comunidad'] as String?,
    fechaSiembra: DateTime.parse(json['fechaSiembra'] as String),
    areaMzs: (json['areaMzs'] as num).toDouble(),
    creadaEn: DateTime.parse(json['creadaEn'] as String),
  );
}

class GuestParcelaStore {
  static const _clave = 'parcelas_invitado';

  Future<List<GuestParcela>> listar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final crudo = prefs.getString(_clave);
      if (crudo == null || crudo.isEmpty) return [];
      final lista = jsonDecode(crudo) as List<dynamic>;
      return lista
          .map((e) => GuestParcela.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<GuestParcela> agregar({
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
    final nueva = GuestParcela(
      idLocal: DateTime.now().microsecondsSinceEpoch.toString(),
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
      creadaEn: DateTime.now(),
    );

    final actuales = await listar();
    actuales.add(nueva);
    await _guardarTodas(actuales);
    return nueva;
  }

  Future<void> eliminar(String idLocal) async {
    final actuales = await listar();
    actuales.removeWhere((p) => p.idLocal == idLocal);
    await _guardarTodas(actuales);
  }

  Future<void> limpiarTodas() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }

  Future<void> _guardarTodas(List<GuestParcela> parcelas) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _clave,
        jsonEncode(parcelas.map((p) => p.toJson()).toList()),
      );
    } catch (_) {}
  }
}
