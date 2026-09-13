import '../../../../core/network/api_client.dart';
import '../models/catalogo.dart';

class CatalogoService {
  final ApiClient _client;

  CatalogoService(this._client);

  Future<List<Cultivo>> obtenerCultivos() async {
    final json = await _client.get('/catalogos/cultivos') as List<dynamic>;
    return json
        .map((e) => Cultivo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<TipoSuelo>> obtenerTiposSuelo() async {
    final json = await _client.get('/catalogos/tipos-suelo') as List<dynamic>;
    return json
        .map((e) => TipoSuelo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EtapaFenologica>> obtenerEtapasFenologicas() async {
    final json =
        await _client.get('/catalogos/etapas-fenologicas') as List<dynamic>;
    return json
        .map((e) => EtapaFenologica.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<EventoClimatico>> obtenerEventosClimaticos() async {
    final json =
        await _client.get('/catalogos/eventos-climaticos') as List<dynamic>;
    return json
        .map((e) => EventoClimatico.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
