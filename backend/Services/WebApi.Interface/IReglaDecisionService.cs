using WebApi.Models;

namespace WebApi.Interface;

public interface IReglaDecisionService {
    Task<List<ReglaDecision>> ObtenerTodas();
    Task<ReglaDecision?> ObtenerPorClave(int eventoClimaticoId, int cultivoId, int etapaFenologicaId, int tipoSueloId);
    Task SembrarReglasIniciales();
    Task AplicarContenidoPreliminar();
}
