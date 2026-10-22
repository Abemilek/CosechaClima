import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/core/cache/clima_publico_cache.dart';
import 'package:mobile/core/config/municipio_centroide.dart';
import 'package:mobile/core/local/local_data_migration.dart';
import 'package:mobile/features/backup/data/services/local_backup_service.dart';
import 'package:mobile/features/bitacora/data/models/bitacora.dart';
import 'package:mobile/features/bitacora/data/services/bitacora_service.dart';
import 'package:mobile/features/clima/data/models/clima.dart';
import 'package:mobile/features/parcela/data/models/parcela_local.dart';
import 'package:mobile/features/parcela/data/services/parcela_local_store.dart';
import 'package:mobile/features/umbral/data/models/umbral.dart';
import 'package:mobile/features/umbral/data/services/umbral_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

PronosticoPublico _dia(int dia, {double? lluvia}) => PronosticoPublico(
  fecha: DateTime(2026, 1, dia),
  temperaturaMax: 30,
  temperaturaMin: 20,
  precipitacion: lluvia,
  vientoVelocidad: 10,
);

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
  });

  group('ClimaPublicoCache', () {
    test(
      'devuelve el pronostico guardado para las mismas coordenadas',
      () async {
        final cache = ClimaPublicoCache();
        await cache.guardar(
          latitud: 11.85,
          longitud: -86.20,
          ubicacionTexto: 'Carazo (aproximado)',
          pronostico: [_dia(1), _dia(2)],
        );

        final guardado = await cache.obtener(
          latitud: 11.851,
          longitud: -86.199,
        );
        expect(guardado, isNotNull);
        expect(guardado!.pronostico.length, 2);
        expect(guardado.ubicacionTexto, 'Carazo (aproximado)');
      },
    );

    test(
      'sin coincidencia exacta devuelve el ultimo pronostico guardado',
      () async {
        final cache = ClimaPublicoCache();
        await cache.guardar(
          latitud: 11.85,
          longitud: -86.20,
          ubicacionTexto: 'Carazo',
          pronostico: [_dia(1)],
        );
        await cache.guardar(
          latitud: 12.13,
          longitud: -86.25,
          ubicacionTexto: 'Managua',
          pronostico: [_dia(1), _dia(2), _dia(3)],
        );

        final guardado = await cache.obtener(latitud: 13.00, longitud: -85.00);
        expect(guardado, isNotNull);
        expect(guardado!.ubicacionTexto, 'Managua');
      },
    );

    test('devuelve null cuando no hay nada guardado', () async {
      final cache = ClimaPublicoCache();
      expect(await cache.obtener(), isNull);
    });
  });

  group('ParcelaLocalStore', () {
    test('crea, actualiza, lista y elimina parcelas sin servidor', () async {
      final store = ParcelaLocalStore();
      final creada = await store.agregar(
        cultivoId: 1,
        cultivoNombre: 'Maíz',
        tipoSueloId: 1,
        tipoSueloNombre: 'Franco',
        etapaFenologicaId: 1,
        latitud: 11.85,
        longitud: -86.20,
        municipio: 'Jinotepe',
        fechaSiembra: DateTime(2026, 5, 1),
        areaMzs: 1.5,
      );

      expect((await store.listar()).single.id, creada.id);

      await store.actualizar(
        ParcelaLocal(
          id: creada.id,
          cultivoId: creada.cultivoId,
          cultivoNombre: creada.cultivoNombre,
          tipoSueloId: creada.tipoSueloId,
          tipoSueloNombre: creada.tipoSueloNombre,
          etapaFenologicaId: creada.etapaFenologicaId,
          latitud: creada.latitud,
          longitud: creada.longitud,
          municipio: creada.municipio,
          comunidad: creada.comunidad,
          fechaSiembra: creada.fechaSiembra,
          areaMzs: 3.0,
          creadaEn: creada.creadaEn,
          actualizadaEn: DateTime.now(),
        ),
      );
      final actualizada = await store.obtener(creada.id);
      expect(actualizada!.areaMzs, 3.0);

      await store.eliminar(creada.id);
      expect(await store.listar(), isEmpty);
    });
  });

  group('LocalDataMigration', () {
    test(
      'convierte la copia de parcelas del servidor en parcelas locales',
      () async {
        SharedPreferences.setMockInitialValues({
          'cache_lista_parcelas': jsonEncode({
            'guardadoEn': DateTime(2026, 10, 1).toIso8601String(),
            'parcelas': [
              {
                'id': 42,
                'usuarioId': 7,
                'cultivoId': 1,
                'etapaFenologicaId': 1,
                'tipoSueloId': 1,
                'fechaSiembra': DateTime(2026, 5, 1).toIso8601String(),
                'areaMzs': 2.5,
                'latitud': 11.85,
                'longitud': -86.20,
                'municipio': 'Jinotepe',
                'comunidad': 'El Rosario',
                'activa': true,
              },
            ],
          }),
        });

        final migradas = await LocalDataMigration.ejecutar();
        expect(migradas, 1);

        final parcelas = await ParcelaLocalStore().listar();
        expect(parcelas.single.id, 'migrada_42');
        expect(parcelas.single.cultivoNombre, isNotEmpty);
        expect(parcelas.single.tipoSueloNombre, isNotEmpty);
        expect(parcelas.single.comunidad, 'El Rosario');
      },
    );

    test('conserva las parcelas locales y agrega las del servidor', () async {
      final store = ParcelaLocalStore();
      await store.agregar(
        cultivoId: 1,
        cultivoNombre: 'Maíz',
        tipoSueloId: 1,
        tipoSueloNombre: 'Franco',
        latitud: 11.85,
        longitud: -86.20,
        municipio: 'Jinotepe',
        fechaSiembra: DateTime(2026, 5, 1),
        areaMzs: 1,
      );
      SharedPreferences.setMockInitialValues({
        'parcelas_invitado': jsonEncode(
          (await store.listar()).map((p) => p.toJson()).toList(),
        ),
        'cache_lista_parcelas': jsonEncode({
          'guardadoEn': DateTime(2026, 10, 1).toIso8601String(),
          'parcelas': [
            {
              'id': 43,
              'cultivoId': 1,
              'tipoSueloId': 1,
              'fechaSiembra': DateTime(2026, 5, 1).toIso8601String(),
              'areaMzs': 2.0,
              'latitud': 11.86,
              'longitud': -86.21,
            },
          ],
        }),
      });

      final migradas = await LocalDataMigration.ejecutar();
      expect(migradas, 1);
      expect((await store.listar()).length, 2);
    });
  });

  group('UmbralService local', () {
    test('guarda y lee los umbrales en el telefono', () async {
      final service = UmbralService();
      await service.guardar(
        const UmbralConfig(
          lluviaIntensaMm: 80,
          vientoFuerteKmh: 35,
          caniculaDias: 6,
          variedadCultivo: 'Híbrido',
          tieneRiego: true,
          horarioSms: '07:00',
        ),
      );

      final leido = await service.obtener();
      expect(leido.lluviaIntensaMm, 80);
      expect(leido.vientoFuerteKmh, 35);
      expect(leido.caniculaDias, 6);
      expect(leido.variedadCultivo, 'Híbrido');
      expect(leido.tieneRiego, isTrue);
      expect(leido.horarioSms, '07:00');
    });

    test('migra los umbrales pendientes de la version anterior', () async {
      SharedPreferences.setMockInitialValues({
        'umbrales_pendientes': [
          jsonEncode({
            'lluviaIntensaMm': 70,
            'vientoFuerteKmh': 30,
            'caniculaDias': 5,
            'variedadCultivo': 'Criollo',
            'tieneRiego': false,
            'horarioSms': '06:00',
          }),
        ],
      });

      final leido = await UmbralService().obtener();
      expect(leido.lluviaIntensaMm, 70);
      expect(leido.vientoFuerteKmh, 30);
      expect(leido.caniculaDias, 5);
    });
  });

  group('BitacoraService local', () {
    test('crea entradas, marca acciones y genera resumen', () async {
      final service = BitacoraService();
      final entrada = await service.crear(
        BitacoraRequest(
          parcelaId: 'p_1',
          fecha: DateTime(2026, 10, 22),
          eventoClimaticoId: 1,
          nivelRiesgo: 'Alto',
          accion1Texto: 'Drenar el terreno',
          accion2Texto: 'Asegurar las plantas',
          accion3Texto: 'Revisar el drenaje',
        ),
      );

      expect((await service.obtenerDeParcela('p_1')).length, 1);
      await service.marcarAccion(entrada.id, 1);
      final actualizada = (await service.obtenerDeParcela('p_1')).single;
      expect(actualizada.accion1Completada, isTrue);
      expect(actualizada.accion2Completada, isFalse);

      final resumen = await service.obtenerResumen(parcelaId: 'p_1');
      expect(resumen, contains('Registros: 1'));
      expect(resumen, contains('Riesgo máximo registrado: Alto'));
    });
  });

  group('Copia de seguridad local', () {
    test('exporta y restaura parcelas, umbrales y bitacora', () async {
      final store = ParcelaLocalStore();
      final parcela = await store.agregar(
        cultivoId: 1,
        cultivoNombre: 'Maíz',
        tipoSueloId: 1,
        tipoSueloNombre: 'Franco',
        latitud: 11.85,
        longitud: -86.20,
        municipio: 'Jinotepe',
        fechaSiembra: DateTime(2026, 5, 1),
        areaMzs: 2,
      );
      await UmbralService().guardar(const UmbralConfig(lluviaIntensaMm: 90));
      await BitacoraService().crear(
        BitacoraRequest(
          parcelaId: parcela.id,
          fecha: DateTime(2026, 10, 22),
          eventoClimaticoId: 6,
          nivelRiesgo: 'Bajo',
          accion1Texto: 'Seguir con el manejo habitual',
          accion2Texto: '-',
          accion3Texto: '-',
        ),
      );

      final respaldo = await LocalBackupService().exportar();
      await store.limpiarTodas();
      await UmbralService().guardar(UmbralConfig.recomendado);
      await BitacoraService().reemplazarTodas([]);

      final resultado = await LocalBackupService().importar(respaldo);
      expect(resultado.parcelas, 1);
      expect(resultado.entradasBitacora, 1);
      expect((await store.listar()).single.id, parcela.id);
      expect((await UmbralService().obtener()).lluviaIntensaMm, 90);
      expect((await BitacoraService().obtenerTodas()).length, 1);
    });
  });

  group('MunicipioCentroide', () {
    test('resuelve cabeceras y municipios de Carazo', () {
      expect(MunicipioCentroide.latitud('Jinotepe'), closeTo(11.85, 0.001));
      expect(MunicipioCentroide.longitud('Managua'), closeTo(-86.251, 0.001));
      expect(MunicipioCentroide.conocido('Departamento inventado'), isFalse);
    });

    test('encuentra el municipio mas cercano a unas coordenadas', () {
      expect(MunicipioCentroide.masCercano(11.85, -86.20), 'Jinotepe');
      expect(MunicipioCentroide.masCercano(12.14, -86.25), 'Managua');
      expect(MunicipioCentroide.masCercano(11.97, -86.09), 'Masaya');
    });
  });
}
