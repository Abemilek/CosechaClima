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
}
