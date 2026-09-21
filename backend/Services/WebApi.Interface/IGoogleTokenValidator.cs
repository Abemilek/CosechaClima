using WebApi.Models;

namespace WebApi.Interface;

public interface IGoogleTokenValidator
{
    Task<UsuarioGoogle?> ValidarIdToken(string idToken);
}
