import '../../../../core/network/api_client.dart';
import '../models/parcela.dart';

class ParcelaService {
  final ApiClient _client;

  ParcelaService(this._client);

  Future<List<Parcela>> obtenerMisParcelas() async {
    final json = await _client.get('/parcelas/mias') as List<dynamic>;
    return json
        .map((e) => Parcela.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Parcela> obtenerPorId(int id) async {
    final json = await _client.get('/parcelas/$id');
    return Parcela.fromJson(json as Map<String, dynamic>);
  }

  Future<int> crear(ParcelaRequest request) async {
    final json = await _client.post('/parcelas', body: request.toJson());
    return (json as Map<String, dynamic>)['id'] as int;
  }

  Future<void> actualizar(int id, ParcelaUpdateRequest request) async {
    assert(
      !request.estaVacio,
      'ParcelaUpdateRequest no puede estar completamente vacío',
    );
    await _client.put('/parcelas/$id', body: request.toJson());
  }

  Future<void> actualizarEtapa(int parcelaId, int etapaId) async {
    await _client.put('/parcelas/$parcelaId/etapa/$etapaId');
  }

  Future<void> eliminar(int id) async {
    await _client.delete('/parcelas/$id');
  }
}
