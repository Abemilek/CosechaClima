namespace WebApi.Models;

public class EtapaFenologica {
    public int Id {get; set; }
    public string Nombre {get; set; } = string.Empty;
    public string? Descripcion {get; set; }
    public int? DiasDesdeSiembra {get; set; } 
}
