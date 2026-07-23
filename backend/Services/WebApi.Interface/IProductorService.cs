using WebApi.Models;

namespace WebApi.Interface;

public interface IProductorService {
    Task<int> Registrar (Productor productor);
    Task<Productor?> ObtenerPorId (int id);
    Task<Productor?> ObtenerPorUSuario (int usuarioId);
    Task<List<Productor>> ObtenerTodos();
    Task <bool> ActualizarUbicacion(int id, string minicipio, string? comunidad);
}
