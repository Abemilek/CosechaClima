namespace WebApi.Models;

public class PronosticoPublico
{
    public DateTime Fecha { get; set; }
    public decimal? TemperaturaMax { get; set; }
    public decimal? TemperaturaMin { get; set; }
    public decimal? Precipitacion { get; set; }
    public decimal? VientoVelocidad { get; set; }
}
