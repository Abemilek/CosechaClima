import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../security/secure_storage.dart';
import 'api_exception.dart';

enum _ResultadoRefresh { exito, rechazado, sinConexion }

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static VoidCallback? onSessionExpired;

  static Future<_ResultadoRefresh>? _refrescando;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse(
      '${ApiConfig.baseUrl}${ApiConfig.apiPrefix}$cleanPath',
    ).replace(queryParameters: query?.map((k, v) => MapEntry(k, v.toString())));
  }

  Future<Map<String, String>> _headers({bool auth = true}) async {
    final headers = {'Content-Type': 'application/json'};
    if (auth) {
      final token = await SecureStorage.read(SecureStorageKeys.token);
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) => _send(auth: auth, () async {
    final res = await _client
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(ApiConfig.timeout);
    return _handle(res);
  });

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send(auth: auth, () async {
        final res = await _client
            .post(
              _uri(path),
              headers: await _headers(auth: auth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(ApiConfig.timeout);
        return _handle(res);
      });

  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send(auth: auth, () async {
        final res = await _client
            .put(
              _uri(path),
              headers: await _headers(auth: auth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(ApiConfig.timeout);
        return _handle(res);
      });

  Future<dynamic> delete(String path, {bool auth = true}) =>
      _send(auth: auth, () async {
        final res = await _client
            .delete(_uri(path), headers: await _headers(auth: auth))
            .timeout(ApiConfig.timeout);
        return _handle(res);
      });

  Future<dynamic> _send(
    Future<dynamic> Function() request, {
    required bool auth,
  }) async {
    try {
      return await _ejecutar(request);
    } on ApiException catch (e) {
      if (!auth || !e.esNoAutorizado) rethrow;

      switch (await _refrescarSesion()) {
        case _ResultadoRefresh.exito:
          try {
            return await _ejecutar(request);
          } on ApiException catch (e2) {
            if (e2.esNoAutorizado) onSessionExpired?.call();
            rethrow;
          }
        case _ResultadoRefresh.rechazado:
          onSessionExpired?.call();
          rethrow;
        case _ResultadoRefresh.sinConexion:
          throw const NetworkException();
      }
    }
  }

  Future<dynamic> _ejecutar(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on TimeoutException {
      throw const TimeoutApiException();
    } on SocketException {
      throw const NetworkException();
    } on HttpException {
      throw const NetworkException();
    } on FormatException {
      throw const NetworkException('Respuesta inválida del servidor.');
    }
  }

  Future<_ResultadoRefresh> _refrescarSesion() {
    final enCurso = _refrescando;
    if (enCurso != null) return enCurso;

    final nuevo = _renovar().whenComplete(() => _refrescando = null);
    _refrescando = nuevo;
    return nuevo;
  }

  Future<_ResultadoRefresh> _renovar() async {
    final refresh = await SecureStorage.read(SecureStorageKeys.refreshToken);
    if (refresh == null || refresh.isEmpty) return _ResultadoRefresh.rechazado;

    try {
      final res = await _client
          .post(
            _uri('/auth/refresh'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refreshToken': refresh}),
          )
          .timeout(ApiConfig.timeout);

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        final token = json['token'] as String?;
        final nuevoRefresh = json['refreshToken'] as String?;
        if (token == null || nuevoRefresh == null) {
          return _ResultadoRefresh.rechazado;
        }
        await SecureStorage.write(SecureStorageKeys.refreshToken, nuevoRefresh);
        await SecureStorage.write(SecureStorageKeys.token, token);
        return _ResultadoRefresh.exito;
      }

      if (res.statusCode == 400 ||
          res.statusCode == 401 ||
          res.statusCode == 403) {
        return _ResultadoRefresh.rechazado;
      }

      return _ResultadoRefresh.sinConexion;
    } on TimeoutException {
      return _ResultadoRefresh.sinConexion;
    } on SocketException {
      return _ResultadoRefresh.sinConexion;
    } on HttpException {
      return _ResultadoRefresh.sinConexion;
    } on http.ClientException {
      return _ResultadoRefresh.sinConexion;
    } on FormatException {
      return _ResultadoRefresh.sinConexion;
    }
  }

  dynamic _handle(http.Response res) {
    final status = res.statusCode;
    final rawBody = res.body.isEmpty ? null : res.body;

    if (status >= 200 && status < 300) {
      if (rawBody == null) return null;
      try {
        return jsonDecode(rawBody);
      } catch (_) {
        return rawBody;
      }
    }

    String? message;
    if (rawBody != null) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          message =
              (decoded['title'] ?? decoded['mensaje'] ?? decoded['message'])
                  ?.toString();
        }
      } catch (_) {}
    }

    if (status == 401) {
      throw ApiException(401, message ?? 'Tu sesión expiró. Iniciá sesión.');
    }

    if (message == null) {
      throw const NetworkException(
        'No se pudo conectar con el servidor. Revisá tu conexión.',
      );
    }

    throw ApiException(status, message);
  }
}
