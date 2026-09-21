namespace WebApi.Models;

public class UsuarioGoogle
{
    public string Uid { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string? FotoUrl { get; set; }
}
