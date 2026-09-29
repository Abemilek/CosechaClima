import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificacionRiesgoService {
  NotificacionRiesgoService._();
  static final NotificacionRiesgoService instancia =
      NotificacionRiesgoService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inicializado = false;

  static const _prefsPrefix = 'ultimo_riesgo_parcela_';
  static const _prefsFechaPrefix = 'ultima_notificacion_parcela_';
  static const _ordenRiesgo = {'bajo': 0, 'medio': 1, 'alto': 2};

  static const _intervaloMinimoEntreAvisos = Duration(days: 2);

  Future<void> _asegurarInicializado() async {
    if (_inicializado) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );
    _inicializado = true;
  }

  Future<bool> solicitarPermiso() async {
    await _asegurarInicializado();
    if (Platform.isAndroid) {
      final estado = await Permission.notification.request();
      return estado.isGranted;
    }
    if (Platform.isIOS) {
      final otorgado = await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      return otorgado ?? false;
    }
    return true;
  }

  Future<bool> tienePermiso() async {
    if (Platform.isAndroid) {
      return Permission.notification.isGranted;
    }
    return true;
  }

  Future<void> evaluarCambioDeRiesgo({
    required int parcelaId,
    required String parcelaNombre,
    required String nivelRiesgoActual,
    required String descripcionAlerta,
  }) async {
    if (!await tienePermiso()) return;

    final prefs = await SharedPreferences.getInstance();
    final clave = '$_prefsPrefix$parcelaId';
    final anterior = prefs.getString(clave);

    await prefs.setString(clave, nivelRiesgoActual);

    if (anterior == null) return;

    final ordenAnterior = _ordenRiesgo[anterior.toLowerCase()] ?? 0;
    final ordenActual = _ordenRiesgo[nivelRiesgoActual.toLowerCase()] ?? 0;

    if (ordenActual <= ordenAnterior) return;

    final claveFecha = '$_prefsFechaPrefix$parcelaId';
    final ultimaNotificacionCruda = prefs.getString(claveFecha);
    final esUrgente = nivelRiesgoActual.toLowerCase() == 'alto';

    if (!esUrgente && ultimaNotificacionCruda != null) {
      final ultimaNotificacion = DateTime.tryParse(ultimaNotificacionCruda);
      if (ultimaNotificacion != null &&
          DateTime.now().difference(ultimaNotificacion) <
              _intervaloMinimoEntreAvisos) {
        return;
      }
    }

    await prefs.setString(claveFecha, DateTime.now().toIso8601String());
    await _asegurarInicializado();

    const androidDetails = AndroidNotificationDetails(
      'riesgo_climatico',
      'Cambios de riesgo climático',
      channelDescription:
          'Avisa cuando el riesgo climático de una parcela sube de nivel.',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _plugin.show(
      parcelaId,
      'Riesgo $nivelRiesgoActual en $parcelaNombre',
      descripcionAlerta,
      details,
    );
  }
}
