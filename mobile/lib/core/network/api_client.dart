import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/constants.dart';
import '../security/secure_storage.dart';
import 'api_exception.dart';

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  static VoidCallback? onSessionExpired;

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
  }) => _send(() async {
    final res = await _client
        .get(_uri(path, query), headers: await _headers(auth: auth))
        .timeout(ApiConfig.timeout);
    return _handle(res, auth: auth);
  });

  Future<dynamic> post(String path, {Object? body, bool auth = true}) =>
      _send(() async {
        final res = await _client
            .post(
              _uri(path),
              headers: await _headers(auth: auth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(ApiConfig.timeout);
        return _handle(res, auth: auth);
      });

  Future<dynamic> put(String path, {Object? body, bool auth = true}) =>
      _send(() async {
        final res = await _client
            .put(
              _uri(path),
              headers: await _headers(auth: auth),
              body: body == null ? null : jsonEncode(body),
            )
            .timeout(ApiConfig.timeout);
        return _handle(res, auth: auth);
      });

  Future<dynamic> delete(String path, {bool auth = true}) => _send(() async {
    final res = await _client
        .delete(_uri(path), headers: await _headers(auth: auth))
        .timeout(ApiConfig.timeout);
    return _handle(res, auth: auth);
  });

  Future<dynamic> _send(Future<dynamic> Function() request) async {
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

  dynamic _handle(http.Response res, {required bool auth}) {
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

    if (status == 401 && auth) {
      onSessionExpired?.call();
    }

    String message = 'Error inesperado ($status)';
    if (rawBody != null) {
      try {
        final decoded = jsonDecode(rawBody);
        if (decoded is Map<String, dynamic>) {
          message =
              (decoded['title'] ??
                      decoded['mensaje'] ??
                      decoded['message'] ??
                      message)
                  .toString();
        }
      } catch (_) {
        message = rawBody;
      }
    }

    throw ApiException(status, message);
  }
}
