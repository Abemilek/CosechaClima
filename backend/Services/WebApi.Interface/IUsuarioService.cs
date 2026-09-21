using WebApi.Models;

namespace WebApi.Interface;

public interface IUsuarioService {
    Task<int> RegistrarConEmail(Usuario usuario, string passwordEnTextoPlano);
    Task<Usuario?> AutenticarConEmail(string email, string password);
    Task<Usuario> ObtenerOCrearDesdeGoogle(UsuarioGoogle datosGoogle);
    Task<Usuario?> ObtenerPorId(int id);
    Task<Usuario?> ObtenerPorEmail(string email);
    Task MarcarComoAdmin(int usuarioId);
}
