using System.Threading.Tasks;
using CosechaClima.Models;

namespace CosechaClima.Interface;

public interface IUsuarioService {
    Task<int> Registrar(Usuario usuario);
    Task<Usuario?> Autenticar(string telefono, string pin);
    Task<Usuario?> ObtenerPorId (int id);
    Task<Usuario?> ObtenerPorTelefono (string telefono);
}