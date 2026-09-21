using WebApi.Models;

namespace WebApi.Interface;

public interface ITokenGenerator
{
    string GenerateFor(Usuario usuario);
}
