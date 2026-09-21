namespace WebApi.Models;

public enum ProveedorAuth
{
    Email = 0,
    Google = 1
}

public class Usuario {
    public int Id {get; set; }
    public string Nombre {get; set; } = string.Empty;
    public string Email {get; set; } = string.Empty;
    public string? GoogleUid {get; set; }
    public string? PasswordHash {get; set; }
    public string? PasswordSalt {get; set; }
    public ProveedorAuth Proveedor {get; set; } = ProveedorAuth.Email;
    public string? FotoUrl {get; set; }
    public DateTime FechaRegistro {get; set; } = DateTime.Now;
    public bool Activo {get; set; } = true;
    public bool EsAdmin {get; set; } = false;
}
