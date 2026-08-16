using WebApi.Models;

namespace WebApi.Interface;

public interface IEtapaFenologicaService {
    Task<List<EtapaFenologica>> ObtenerTodas();
    Task<EtapaFenologica> CalcularDesdeFecha(DateTime fechaSiembra);
}