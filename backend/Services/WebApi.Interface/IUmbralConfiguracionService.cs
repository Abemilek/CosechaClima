using WebApi.Models;

namespace WebApi.Interface;

public interface IUmbralConfiguracionService {
    Task<int> CrearOActualizar (UmbralConfiguracion Umbral);
    Task<UmbralConfiguracion?> ObtenerPorUsuario (int usuarioId);
    Task<bool> ActualizarUmbrales (int id, int? lluvia, int? viento, int? canicula);
}
