using System.Threading.Tasks;
using CosechaClima.Models;

namespace CosechaClima.Interface;

public interface IAlertaService {
    // generar la alterta con sus 3 acciones recomendadas
    Task<int> Generar (Alerta alerta, List<AccionRecomendada>acciones);
    Task<List<Alerta>> ObtenerAlertasActivas(int usuarioId);
    Task<Alerta> ObtenerPorId (int id);
    Task<List<Alerta>> ObtenerHisorial (int usuarioId, int limite = 20);
    Task<bool> MarcarComoLeida (int alertaId);
    Task<List<AccionRecomendada>> ObtenerAcciones(int alertaId);
    Task<bool> MarcarAccionCompletada (int accionId);
}