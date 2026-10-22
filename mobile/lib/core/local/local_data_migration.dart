import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../core/config/municipio_centroide.dart';
import '../../core/motor/reglas_repository.dart';
import '../../features/parcela/data/models/parcela_local.dart';
import '../../features/parcela/data/services/parcela_local_store.dart';

/// Migración de una sola vez para instalaciones que venían del modo con
/// servidor. Si la app guardó una copia de la lista de parcelas, la convierte
/// en parcelas locales para que el productor no pierda su información.
class LocalDataMigration {
  LocalDataMigration._();

  static const _claveCopiaServidor = 'cache_lista_parcelas';
  static const _claveHecha = 'migracion_local_desde_servidor_v1';

  static Future<int> ejecutar() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_claveHecha) ?? false) return 0;

      final store = ParcelaLocalStore();
      final existentes = await store.listar();
      final ids = existentes.map((p) => p.id).toSet();

      final crudo = prefs.getString(_claveCopiaServidor);
      if (crudo == null || crudo.isEmpty) {
        await prefs.setBool(_claveHecha, true);
        return 0;
      }

      final paquete = await ReglasRepository.instancia.obtener();
      final data = jsonDecode(crudo) as Map<String, dynamic>;
      final lista = data['parcelas'] as List<dynamic>? ?? [];
      final migradas = <ParcelaLocal>[];

      for (final item in lista) {
        try {
          final json = Map<String, dynamic>.from(item as Map);
          final cultivoId = (json['cultivoId'] as num).toInt();
          final sueloId = (json['tipoSueloId'] as num).toInt();
          final etapaId = (json['etapaFenologicaId'] as num?)?.toInt();
          final municipio = json['municipio'] as String?;

          final fechaSiembra = DateTime.tryParse(
            json['fechaSiembra'] as String? ?? '',
          );
          if (fechaSiembra == null) continue;

          var latitud = (json['latitud'] as num?)?.toDouble();
          var longitud = (json['longitud'] as num?)?.toDouble();
          if (latitud == null || longitud == null) {
            latitud = MunicipioCentroide.latitud(municipio);
            longitud = MunicipioCentroide.longitud(municipio);
          }
          if (latitud == null || longitud == null) continue;

          final cultivos = paquete.cultivos
              .where((c) => c.id == cultivoId)
              .toList();
          final suelos = paquete.tiposSuelo
              .where((s) => s.id == sueloId)
              .toList();
          final id = 'migrada_${json['id']}';
          if (!ids.add(id)) continue;

          migradas.add(
            ParcelaLocal(
              id: id,
              cultivoId: cultivoId,
              cultivoNombre: cultivos.isEmpty
                  ? 'Cultivo'
                  : cultivos.first.nombre,
              tipoSueloId: sueloId,
              tipoSueloNombre: suelos.isEmpty ? 'Suelo' : suelos.first.nombre,
              etapaFenologicaId: etapaId,
              latitud: latitud,
              longitud: longitud,
              municipio: municipio,
              comunidad: json['comunidad'] as String?,
              fechaSiembra: fechaSiembra,
              areaMzs: (json['areaMzs'] as num).toDouble(),
              creadaEn: DateTime.now(),
              actualizadaEn: DateTime.now(),
            ),
          );
        } catch (_) {
          // Una parcela dañada no debe impedir migrar las demás.
        }
      }

      if (migradas.isNotEmpty) {
        await store.reemplazarTodas([...existentes, ...migradas]);
      }
      await prefs.setBool(_claveHecha, true);
      return migradas.length;
    } catch (_) {
      return 0;
    }
  }
}
