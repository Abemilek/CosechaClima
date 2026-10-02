import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/cache/catalogo_cache.dart';
import 'package:mobile/core/cache/clima_publico_cache.dart';
import 'package:mobile/core/config/municipio_centroide.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/features/catalogo/data/models/catalogo.dart';
import 'package:mobile/features/catalogo/data/services/catalogo_service.dart';
import 'package:mobile/features/clima/data/models/clima.dart';
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

    const canalSecureStorage = MethodChannel(
      'plugins.it_nomads.com/flutter_secure_storage',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(canalSecureStorage, (call) async => null);

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

  group('CatalogoService sin conexion', () {
    test('cae al cache guardado cuando falla la red', () async {
      final cache = CatalogoCache();
      await cache.guardarCultivos([
        Cultivo(id: 1, nombre: 'Maíz'),
        Cultivo(id: 2, nombre: 'Frijol'),
      ]);

      final client = MockClient(
        (_) async => throw const SocketException('sin red'),
      );
      final service = CatalogoService(ApiClient(client: client));

      final cultivos = await service.obtenerCultivos();
      expect(cultivos.map((c) => c.nombre), ['Maíz', 'Frijol']);
    });

    test('guarda los catalogos descargados para la proxima vez', () async {
      final client = MockClient(
        (_) async => http.Response(
          '[{"id":1,"nombre":"Arroz","nombreCientifico":null}]',
          200,
        ),
      );
      final service = CatalogoService(ApiClient(client: client));

      await service.obtenerCultivos();
      // el guardado en cache es "fire and forget": le damos un turno
      await pumpEventQueue();

      final cache = CatalogoCache();
      final guardados = await cache.obtenerCultivos();
      expect(guardados, isNotNull);
      expect(guardados!.single.nombre, 'Arroz');
    });
  });

  group('UmbralService sin conexion', () {
    test('encola los umbrales y los sube al recuperar la conexion', () async {
      final offline = UmbralService(
        ApiClient(
          client: MockClient((_) async => throw const SocketException('x')),
        ),
      );
      await offline.guardar(UmbralRequest(horarioSms: '06:00'));

      http.Request? capturada;
      final online = UmbralService(
        ApiClient(
          client: MockClient((request) async {
            capturada = request;
            return http.Response('{"id":7}', 200);
          }),
        ),
      );
      await online.sincronizarPendientes();

      expect(capturada, isNotNull);
      expect(capturada!.url.path, '/api/umbrales');
      expect(capturada!.method, 'POST');
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
