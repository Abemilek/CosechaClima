import '../../../../core/network/api_client.dart';
import '../models/clima.dart';

class ClimaService {
  final ApiClient _client;

  ClimaService(this._client);

  Future<DatosClimaticos> actualizar(int parcelaId) async {
    final json = await _client.post('/clima/actualizar/$parcelaId');
    return DatosClimaticos.fromJson(json as Map<String, dynamic>);
  }

  Future<List<PronosticoPublico>> obtenerPronosticoPublico({
    required double latitud,
    required double longitud,
  }) async {
    final json = await _client.get(
      '/clima/pronostico',
      auth: false,
      query: {'latitud': latitud, 'longitud': longitud},
    );

    return (json as List<dynamic>)
        .map((e) => PronosticoPublico.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
