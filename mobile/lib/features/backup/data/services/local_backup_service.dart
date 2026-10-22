import 'dart:convert';

import '../../../../core/cache/evaluacion_local_cache.dart';
import '../../../../core/config/environment.dart';
import '../../../bitacora/data/models/bitacora.dart';
import '../../../bitacora/data/services/bitacora_service.dart';
import '../../../parcela/data/models/parcela_local.dart';
import '../../../parcela/data/services/parcela_local_store.dart';
import '../../../umbral/data/models/umbral.dart';
import '../../../umbral/data/services/umbral_service.dart';

class ResultadoImportacion {
  final int parcelas;
  final int entradasBitacora;

  const ResultadoImportacion({
    required this.parcelas,
    required this.entradasBitacora,
  });
}

/// Copia de seguridad portable de todos los datos locales.
///
/// Se usa la clipboard para exportar/importar sin agregar permisos ni
/// dependencias de archivos. El JSON también sirve para guardarlo donde el
/// productor prefiera.
class LocalBackupService {
  static const _app = 'CosechaClima';
  static const _formato = 1;

  Future<String> exportar() async {
    final parcelas = await ParcelaLocalStore().listar();
    final umbral = await UmbralService().obtener();
    final bitacora = await BitacoraService().obtenerTodas();

    return const JsonEncoder.withIndent('  ').convert({
      'app': _app,
      'formato': _formato,
      'version': Environment.version,
      'exportadoEn': DateTime.now().toIso8601String(),
      'parcelas': parcelas.map((p) => p.toJson()).toList(),
      'umbral': umbral.toJson(),
      'bitacora': bitacora.map((e) => e.toJson()).toList(),
    });
  }

  Future<ResultadoImportacion> importar(String texto) async {
    final decoded = jsonDecode(texto);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('El respaldo no tiene el formato esperado.');
    }
    if (decoded['app'] != _app) {
      throw const FormatException('Este respaldo no pertenece a CosechaClima.');
    }
    if ((decoded['formato'] as num?)?.toInt() != _formato) {
      throw const FormatException(
        'El respaldo tiene una versión que esta app no puede leer.',
      );
    }

    final parcelasJson = decoded['parcelas'] as List<dynamic>? ?? [];
    final parcelas = parcelasJson
        .map((e) => ParcelaLocal.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    final umbralJson = decoded['umbral'] as Map<String, dynamic>?;
    final umbral = umbralJson == null
        ? UmbralConfig.recomendado
        : UmbralConfig.fromJson(umbralJson);

    final bitacoraJson = decoded['bitacora'] as List<dynamic>? ?? [];
    final entradas = bitacoraJson
        .map((e) => BitacoraEntry.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();

    await ParcelaLocalStore().reemplazarTodas(parcelas);
    await UmbralService().guardar(umbral);
    await BitacoraService().reemplazarTodas(entradas);
    await EvaluacionLocalCache().limpiarTodas();

    return ResultadoImportacion(
      parcelas: parcelas.length,
      entradasBitacora: entradas.length,
    );
  }
}
