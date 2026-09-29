using WebApi.Models;

namespace WebApi.Interface;

public interface IReglaDecisionService {
    Task<List<ReglaDecision>> ObtenerTodas();
    Task<ReglaDecision?> ObtenerPorClave(int eventoClimaticoId, int cultivoId, int etapaFenologicaId, int tipoSueloId);
    Task SembrarReglasIniciales();
    Task AplicarContenidoPreliminar();
    Task<ReglaDecision?> ObtenerPorId(int id);
    Task<bool> ActualizarContenido(int id, string nivelRiesgo, string accion1, string accion2, string accion3, string descripcionAlerta);
    Task<bool> CambiarActiva(int id, bool activa);
}
