import 'package:shared_preferences/shared_preferences.dart';

import '../network/api_client.dart';

/// El semáforo se calcula en el teléfono; esto solo le avisa al servidor QUÉ
/// evento se detectó para que el panel de auditoría de alertas siga funcionando.
/// El texto de las acciones lo pone el servidor desde sus reglas, no la app.
/// Es "mejor esfuerzo": si falla (sin red, etc.) no pasa nada y se reintenta
/// la próxima vez que cambie el resultado.
class AlertaReporter {
  final ApiClient _client;

  AlertaReporter(this._client);

  Future<void> reportarSiCambio({
    required int parcelaId,
    required int eventoClimaticoId,
    required DateTime fecha,
  }) async {
    try {
      final dia = _soloFecha(fecha);
      final huella = '$dia|$eventoClimaticoId';
      final prefs = await SharedPreferences.getInstance();
      final clave = 'alerta_reportada_$parcelaId';
      if (prefs.getString(clave) == huella) return;

      await _client.put(
        '/alertas/parcela/$parcelaId',
        body: {'eventoClimaticoId': eventoClimaticoId, 'fecha': dia},
      );
      await prefs.setString(clave, huella);
    } catch (_) {
      // Mejor esfuerzo.
    }
  }

  static String _soloFecha(DateTime f) {
    final mes = f.month.toString().padLeft(2, '0');
    final dia = f.day.toString().padLeft(2, '0');
    return '${f.year}-$mes-$dia';
  }
}
