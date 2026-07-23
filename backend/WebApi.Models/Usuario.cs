namespace WebApi.Models;

public class Usuario {
    public int Id {get; set; }
    public string Nombre {get; set; } = string.Empty;
    public string Telefono {get; set; } = string.Empty;
    public string PinHash {get; set; } = string.Empty;
    public string PinSalt {get; set; } = string.Empty;
    public DateTime FechaRegistro {get; set; } = DateTime.Now;
    public bool Activo {get; set; } = true;
}
