namespace WebApi.Models;

/// <summary>
/// Paquete completo que la app descarga para calcular alertas en el dispositivo:
/// catalogos + todas las reglas activas. Se identifica con una version (hash del contenido);
/// la app lo pide con If-None-Match y el servidor responde 304 si no cambio.
/// </summary>
public class PaqueteReglas
{
    public string Version { get; set; } = string.Empty;
    public DateTime GeneradoEn { get; set; } = DateTime.UtcNow;
    public List<EventoClimatico> Eventos { get; set; } = new();
    public List<Cultivo> Cultivos { get; set; } = new();
    public List<TipoSuelo> TiposSuelo { get; set; } = new();
    public List<EtapaFenologica> Etapas { get; set; } = new();
    public List<ReglaPaquete> Reglas { get; set; } = new();
}

public class ReglaPaquete
{
    public int EventoClimaticoId { get; set; }
    public int CultivoId { get; set; }
    public int EtapaFenologicaId { get; set; }
    public int TipoSueloId { get; set; }
    public string NivelRiesgo { get; set; } = string.Empty;
    public string Accion1 { get; set; } = string.Empty;
    public string Accion2 { get; set; } = string.Empty;
    public string Accion3 { get; set; } = string.Empty;
    public string DescripcionAlerta { get; set; } = string.Empty;
}
