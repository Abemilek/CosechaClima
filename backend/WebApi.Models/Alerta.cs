namespace WebApi.Models;

public class Alerta {
    public int Id {get; set; }
    public int UsuarioId {get; set; }
    public int ParcelaId {get; set; }
    public DateTime Fecha {get; set; }
    public int EventoClimaticoId {get; set; }
    public string NivelRiesgo {get; set;} = string.Empty;
    public string Accion1 {get; set; } = string.Empty;
    public string Accion2 {get; set; } = string.Empty;
    public string Accion3 {get; set; } = string.Empty;
    public string DescripcionAlerta {get; set; } = string.Empty;
    public DateTime FechaGeneracion {get; set; } = DateTime.Now;
}