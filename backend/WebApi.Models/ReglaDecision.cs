namespace WebApi.Models;

public class ReglaDecision {
    public int Id {get; set; }
    public int EventoClimaticoId {get; set; }
    public int CultivoId {get; set; }
    public int EtapaFenologicaId {get; set; }
    public int TipoSueloId {get; set; }
    public string NivelRiesgo {get; set; } = string.Empty;
    public string Accion1 {get; set; } = string.Empty;
    public string Accion2 {get; set; } = string.Empty;
    public string Accion3 {get; set; } = string.Empty;
    public string DescripcionAlerta {get; set; } = string.Empty;
}
