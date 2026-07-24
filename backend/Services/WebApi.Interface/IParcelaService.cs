using WebApi.Models;

namespace WebApi.Interface;

public interface IParcelaService {
    Task<int> Registrar (Parcela parcela);
    Task<Parcela> ObtenerPorId (int id);
    Task<List<Parcela>> ObtenerPorUsuario(int usuarioId);
    Task<bool> ActualizarEtapa (int parcelaId, int etapaId);
    Task<bool> Eliminar(int id);
}
