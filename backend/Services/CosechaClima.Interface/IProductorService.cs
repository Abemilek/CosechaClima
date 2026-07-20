using System.Runtime.CompilerServices;
using System.Threading.Tasks;
using CosechaClima.Models;

namespace CosechaClima.Interface;

public interface IProductorService {
    //cada productor esta vinculado a un usuario
    Task<int> Registrar (Productor productor);
    Task<Productor?> ObtenerPorId (int id);
    Task<Productor?> ObtenerPorUSuario (int usuarioId);
    Task<List<Productor>> ObtenerTodos();
    Task <bool> ActualizarUbicacion(int id, string minicipio, string? comunidad);
}