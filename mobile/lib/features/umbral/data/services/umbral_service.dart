import '../../../../core/network/api_client.dart';
import '../../../../core/network/api_exception.dart';
import '../models/umbral.dart';

class UmbralService {
  final ApiClient _client;

  UmbralService(this._client);

  Future<Umbral?> obtenerMios() async {
    try {
      final json = await _client.get('/umbrales/mios');
      return Umbral.fromJson(json as Map<String, dynamic>);
    } on ApiException catch (e) {
      if (e.esNoEncontrado) return null;
      rethrow;
    }
  }

  Future<int> guardar(UmbralRequest request) async {
    final json = await _client.post('/umbrales', body: request.toJson());
    return (json as Map<String, dynamic>)['id'] as int;
  }
}
