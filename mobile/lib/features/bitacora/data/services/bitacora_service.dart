import '../../../../core/network/api_client.dart';
import '../models/bitacora.dart';

class BitacoraService {
  final ApiClient _client;

  BitacoraService(this._client);

  Future<List<BitacoraEntry>> obtenerMias() async {
    final json = await _client.get('/logs/mias') as List<dynamic>;
    return json
        .map((e) => BitacoraEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<int> crear(BitacoraRequest request) async {
    final json = await _client.post('/logs', body: request.toJson());
    return (json as Map<String, dynamic>)['id'] as int;
  }

  Future<void> marcarAccion(int entradaId, int numeroAccion) async {
    assert(numeroAccion >= 1 && numeroAccion <= 3);
    await _client.put('/logs/$entradaId/action/$numeroAccion');
  }

  Future<String> obtenerResumen() async {
    final json = await _client.get('/logs/mias/summary');
    return (json as Map<String, dynamic>)['summary'] as String;
  }
}
