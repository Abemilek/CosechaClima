namespace WebApi.Models;

public class Alerta {
    public int Id {get; set; }
    public int UsuarioId {get; set; }
    public int ParcelaId {get; set; }
    public DateTime FechaGeneracion {get; set; } = DateTime.Now;
    public DateTime FechaAlerta {get; set; }
    public string NivelRiesgo {get; set; } = string.Empty;
    public int EventoClimaticoId {get; set; }
    public string Descripcion {get; set; } = string.Empty;
    public string Semaforo {get; set; } = "green";
    public bool Leida {get; set; } = false;
    public bool SmsEnviado {get; set; } = false;
}
