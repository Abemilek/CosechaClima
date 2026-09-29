using WebApi.Models;

namespace WebApi.Interface;

public interface IUsuarioService {
    Task<int> RegistrarConEmail(Usuario usuario, string passwordEnTextoPlano);
    Task<Usuario?> AutenticarConEmail(string email, string password);
    Task<Usuario> ObtenerOCrearDesdeGoogle(UsuarioGoogle datosGoogle);
    Task<Usuario?> ObtenerPorId(int id);
    Task<Usuario?> ObtenerPorEmail(string email);
    Task MarcarComoAdmin(int usuarioId);
    Task<List<Usuario>> ListarTodos();
    Task<bool> CambiarRol(int usuarioId, bool esAdmin);
    Task<bool> CambiarActivo(int usuarioId, bool activo);
}
