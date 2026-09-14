import '../../../../core/network/api_client.dart';
import '../models/clima.dart';

class ClimaService {
  final ApiClient _client;

  ClimaService(this._client);

  Future<DatosClimaticos> actualizar(int parcelaId) async {
    final json = await _client.post('/clima/actualizar/$parcelaId');
    return DatosClimaticos.fromJson(json as Map<String, dynamic>);
  }
}
