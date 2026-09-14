import '../../../../core/network/api_client.dart';
import '../models/regla_decision.dart';

class ReglaDecisionService {
  final ApiClient _client;

  ReglaDecisionService(this._client);

  Future<List<ReglaDecision>> obtenerTodas() async {
    final json = await _client.get('/reglas') as List<dynamic>;
    return json
        .map((e) => ReglaDecision.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> sembrarReglasIniciales() async {
    await _client.post('/reglas/sembrar');
  }

  Future<void> aplicarContenidoPreliminar() async {
    await _client.post('/reglas/aplicar-contenido-preliminar');
  }
}
