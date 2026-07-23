using WebApi.Models;

namespace WebApi.Interface;

public interface IAlertaService {
    Task<int> Generar (Alerta alerta, List<AccionRecomendada>acciones);
    Task<List<Alerta>> ObtenerAlertasActivas(int usuarioId);
    Task<Alerta> ObtenerPorId (int id);
    Task<List<Alerta>> ObtenerHisorial (int usuarioId, int limite = 20);
    Task<bool> MarcarComoLeida (int alertaId);
    Task<List<AccionRecomendada>> ObtenerAcciones(int alertaId);
    Task<bool> MarcarAccionCompletada (int accionId);
}
