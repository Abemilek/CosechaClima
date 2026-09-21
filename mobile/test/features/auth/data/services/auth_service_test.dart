import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  group('AuthService.registrarConEmail', () {
    test('envía POST a /api/auth/register con el body correcto', () async {
      http.Request? peticionCapturada;

      final mockClient = MockClient((request) async {
        peticionCapturada = request;
        return http.Response(
          jsonEncode({
            'token': 'token-de-prueba',
            'nombre': 'Carlos',
            'email': 'carlos@correo.com',
            'esAdmin': false,
          }),
          200,
        );
      });

      final service = AuthService(ApiClient(client: mockClient));

      await service.registrarConEmail(
        nombre: 'Carlos',
        email: 'carlos@correo.com',
        password: 'contrasena-larga',
      );

      expect(peticionCapturada, isNotNull);
      expect(peticionCapturada!.method, 'POST');
      expect(peticionCapturada!.url.path, '/api/auth/register');

      final body = jsonDecode(peticionCapturada!.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Carlos');
      expect(body['email'], 'carlos@correo.com');
      expect(body['password'], 'contrasena-larga');
    });

    test(
      'lanza ApiException con el mensaje del backend si el correo ya existe',
      () async {
        final mockClient = MockClient((request) async {
          return http.Response(
            jsonEncode({'mensaje': 'ya existe una cuenta con este correo'}),
            409,
          );
        });

        final service = AuthService(ApiClient(client: mockClient));

        await expectLater(
          service.registrarConEmail(
            nombre: 'Carlos',
            email: 'carlos@correo.com',
            password: 'contrasena-larga',
          ),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 409)
                .having(
                  (e) => e.message,
                  'message',
                  'ya existe una cuenta con este correo',
                ),
          ),
        );
      },
    );
  });
}
