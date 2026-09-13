import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mobile/core/network/api_client.dart';
import 'package:mobile/core/network/api_exception.dart';
import 'package:mobile/features/auth/data/services/auth_service.dart';

void main() {
  group('AuthService.registrar', () {
    test('envía POST a /api/auth/register con el body correcto', () async {
      http.Request? capturedRequest;

      final mockClient = MockClient((request) async {
        capturedRequest = request;
        return http.Response('', 201);
      });

      final service = AuthService(ApiClient(client: mockClient));

      await service.registrar(
        nombre: 'Carlos',
        telefono: '88887777',
        pin: '1234',
      );

      expect(capturedRequest, isNotNull);
      expect(capturedRequest!.method, 'POST');
      expect(capturedRequest!.url.path, '/api/auth/register');

      final body = jsonDecode(capturedRequest!.body) as Map<String, dynamic>;
      expect(body['nombre'], 'Carlos');
      expect(body['telefono'], '88887777');
      expect(body['pin'], '1234');
    });

    test('lanza ApiException con el mensaje del backend si falla', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({'title': 'El telefono ya esta registrado'}),
          409,
        );
      });

      final service = AuthService(ApiClient(client: mockClient));

      await expectLater(
        service.registrar(nombre: 'Carlos', telefono: '88887777', pin: '1234'),
        throwsA(
          isA<ApiException>()
              .having((e) => e.statusCode, 'statusCode', 409)
              .having(
                (e) => e.message,
                'message',
                'El telefono ya esta registrado',
              ),
        ),
      );
    });
  });
}
