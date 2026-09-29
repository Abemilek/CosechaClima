namespace WebApi.Models;

public class DiaResumenSemanal
{
    public DateTime Fecha { get; set; }
    public string NivelRiesgo { get; set; } = string.Empty;
    public int EventoClimaticoId { get; set; }
    public decimal? TemperaturaMax { get; set; }
    public decimal? TemperaturaMin { get; set; }
    public decimal? Precipitacion { get; set; }
}

public class ResumenSemanal
{
    public List<DiaResumenSemanal> Dias { get; set; } = new();
    public string NivelRiesgoMaximo { get; set; } = "Bajo";
    public DateTime? DiaMasCritico { get; set; }
    public string DescripcionAlerta { get; set; } = string.Empty;
    public List<string> AccionesDeLaSemana { get; set; } = new();
}
