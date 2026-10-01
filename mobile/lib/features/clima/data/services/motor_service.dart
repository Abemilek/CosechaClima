import '../../../../core/network/api_client.dart';
import '../models/clima.dart';

class MotorService {
  final ApiClient _client;

  MotorService(this._client);

  Future<Semaforo> obtenerSemaforo(int parcelaId) async {
    final json = await _client.post(
      '/motor/semaforo',
      body: {'parcelaId': parcelaId},
    );
    return Semaforo.fromJson(json as Map<String, dynamic>);
  }

  Future<ResumenSemanal> obtenerResumenSemanal(int parcelaId) async {
    final json = await _client.get('/motor/resumen-semanal/$parcelaId');
    return ResumenSemanal.fromJson(json as Map<String, dynamic>);
  }

  Future<ResumenSemanal> obtenerResumenSemanalAnonimo({
    required int cultivoId,
    int? etapaFenologicaId,
    required int tipoSueloId,
    required double latitud,
    required double longitud,
    required DateTime fechaSiembra,
  }) async {
    final json = await _client.post(
      '/motor/resumen-semanal-anonimo',
      auth: false,
      body: {
        'cultivoId': cultivoId,
        'etapaFenologicaId': ?etapaFenologicaId,
        'tipoSueloId': tipoSueloId,
        'latitud': latitud,
        'longitud': longitud,
        'fechaSiembra': fechaSiembra.toIso8601String(),
      },
    );
    return ResumenSemanal.fromJson(json as Map<String, dynamic>);
  }
}
