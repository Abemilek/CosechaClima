namespace WebApi.Models;

public class Cultivo
{
    public int Id {get; set; }
    public string Nombre {get; set; } = string.Empty;
    public string? NombreCientifico {get; set; }
}
