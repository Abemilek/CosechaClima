import 'dart:io' show Platform;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

enum EnvironmentTarget {
  auto,
  local,
  docker,
  androidEmulatorLocal,
  androidEmulatorDocker,
  custom,
}

class Environment {
  Environment._();

  static const EnvironmentTarget _current = EnvironmentTarget.auto;

  static const String _customUrl = 'http://192.168.1.50:8080';

  static const bool _backendEnDocker = true;

  static const String local = 'http://127.0.0.1:5005';
  static const String docker = 'http://localhost:8080';
  static const String androidEmulatorLocal = 'http://10.0.2.2:5005';
  static const String androidEmulatorDocker = 'http://10.0.2.2:8080';

  static String? _autoResolved;

  static Future<void> initialize() async {
    if (_current != EnvironmentTarget.auto) return;
    _autoResolved = await _detectar();
  }

  static Future<String> _detectar() async {
    if (kIsWeb) {
      return _backendEnDocker ? docker : local;
    }

    try {
      if (Platform.isAndroid) {
        final info = await DeviceInfoPlugin().androidInfo;
        if (!info.isPhysicalDevice) {
          return _backendEnDocker
              ? androidEmulatorDocker
              : androidEmulatorLocal;
        }
        return _backendEnDocker ? docker : local;
      }

      if (Platform.isIOS) {
        final info = await DeviceInfoPlugin().iosInfo;
        if (!info.isPhysicalDevice) {
          return _backendEnDocker ? docker : local;
        }
        return _backendEnDocker ? docker : local;
      }
    } catch (_) {}

    return _backendEnDocker ? docker : local;
  }

  static String get apiBaseUrl {
    switch (_current) {
      case EnvironmentTarget.auto:
        return _autoResolved ?? (_backendEnDocker ? docker : local);
      case EnvironmentTarget.local:
        return local;
      case EnvironmentTarget.docker:
        return docker;
      case EnvironmentTarget.androidEmulatorLocal:
        return androidEmulatorLocal;
      case EnvironmentTarget.androidEmulatorDocker:
        return androidEmulatorDocker;
      case EnvironmentTarget.custom:
        return _customUrl;
    }
  }

  static const bool isProduction = bool.fromEnvironment('dart.vm.product');
}
