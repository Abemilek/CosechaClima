namespace WebApi.Models;

public class BitacoraCampo {
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public int ParcelaId { get; set; }
    public DateTime Fecha { get; set; }
    public int EventoClimaticoId { get; set; }
    public string NivelRiesgo { get; set; } = string.Empty;
    public string Accion1Texto { get; set; } = string.Empty;
    public string Accion2Texto { get; set; } = string.Empty;
    public string Accion3Texto { get; set; } = string.Empty;
    public bool Accion1Completada { get; set; }
    public bool Accion2Completada { get; set; }
    public bool Accion3Completada { get; set; }
    public string? Notas { get; set; }
    public DateTime FechaSincronizacion { get; set; } = DateTime.Now;
}
