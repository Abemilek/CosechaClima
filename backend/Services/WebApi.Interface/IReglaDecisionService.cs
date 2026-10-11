using WebApi.Models;

namespace WebApi.Interface;

public interface IReglaDecisionService {
    Task<List<ReglaDecision>> ObtenerTodas();
    Task<ReglaDecision?> ObtenerPorClave(int eventoClimaticoId, int cultivoId, int etapaFenologicaId, int tipoSueloId);
    Task SembrarReglasIniciales();

    /// <param name="soloPendientes">
    /// true (por defecto): solo rellena reglas que siguen en PENDIENTE y NO pisa lo que un admin ya edito.
    /// false: sobrescribe todas las reglas del JSON preliminar.
    /// </param>
    Task AplicarContenidoPreliminar(bool soloPendientes = true);
    Task<ReglaDecision?> ObtenerPorId(int id);
    Task<bool> ActualizarContenido(int id, string nivelRiesgo, string accion1, string accion2, string accion3, string descripcionAlerta);
    Task<bool> CambiarActiva(int id, bool activa);

    /// <summary>Catalogos + reglas activas, con version, para que la app calcule en el dispositivo.</summary>
    Task<PaqueteReglas> ObtenerPaquete();
}
