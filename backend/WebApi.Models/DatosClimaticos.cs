namespace WebApi.Models;

public class DatosClimaticos {
    public int Id {get; set; }
    public int ParcelaId {get; set; }
    public DateTime Fecha {get; set; }
    public decimal? TemperaturaMedia {get; set; }
    public decimal? TemperaturaMax {get; set; }
    public decimal? TemperaturaMin {get; set; }
    public decimal? Precipitacion {get; set; }
    public decimal? HumedadRelativa {get; set; }
    public decimal? VientoVelocidad {get; set; }
    public decimal? RadiacionSolar {get; set; }
    public string FuenteNASA {get; set; } = "POWER";
    public DateTime FechaDescarga {get; set; } = DateTime.Now;
}
