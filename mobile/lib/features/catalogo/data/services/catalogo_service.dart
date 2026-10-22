import '../../../../core/motor/reglas_repository.dart';
import '../models/catalogo.dart';

/// Catálogos locales para el asistente de parcela.
///
/// No hay red ni caché remota: los datos salen del paquete de reglas embebido.
class CatalogoService {
  CatalogoService({ReglasRepository? reglas})
    : _reglas = reglas ?? ReglasRepository.instancia;

  final ReglasRepository _reglas;

  Future<List<Cultivo>> obtenerCultivos() async =>
      (await _reglas.obtener()).cultivos;

  Future<List<TipoSuelo>> obtenerTiposSuelo() async =>
      (await _reglas.obtener()).tiposSuelo;

  Future<List<EtapaFenologica>> obtenerEtapasFenologicas() async =>
      (await _reglas.obtener()).etapas;

  Future<List<EventoClimatico>> obtenerEventosClimaticos() async =>
      (await _reglas.obtener()).eventos;
}
