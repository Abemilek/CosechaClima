using WebApi.Models;

namespace WebApi.Interface;

public interface ICatalogoService {
    Task<List<Cultivo>> ObtenerCultivos();
    Task<List<TipoSuelo>> ObtenerTiposSuelo();
    Task<List<EventoClimatico>> ObtenerEventosClimaticos();
    Task<List<EtapaFenologica>> ObtenerEtapasFenologicas();
    Task<bool> CultivoExiste(int id);
    Task<bool> TipoSueloExiste(int id);
    Task<bool> EtapaFenologicaExiste(int id);
}