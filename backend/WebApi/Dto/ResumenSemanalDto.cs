namespace WebApi.Dto;

public class DiaResumenSemanalDto
{
    public DateTime Fecha { get; set; }
    public string NivelRiesgo { get; set; } = string.Empty;
    public decimal? TemperaturaMax { get; set; }
    public decimal? TemperaturaMin { get; set; }
    public decimal? Precipitacion { get; set; }
}

public class ResumenSemanalDto
{
    public List<DiaResumenSemanalDto> Dias { get; set; } = new();
    public string NivelRiesgoMaximo { get; set; } = string.Empty;
    public DateTime? DiaMasCritico { get; set; }
    public string DescripcionAlerta { get; set; } = string.Empty;
    public List<string> AccionesDeLaSemana { get; set; } = new();
}
