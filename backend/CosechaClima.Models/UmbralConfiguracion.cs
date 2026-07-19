using System;

namespace CosechaClima.Models;

public class UmbralConfiguracion {
    public int Id {get; set; }
    public int ProductorId {get; set; }
    public int LluviaIntensaMm {get; set; } = 100;
    public int VientoFuerteKmh {get; set; } = 40;
    public int CaniculaDias {get; set; } = 7;
    public string VariedadCultivo {get; set; } = "Criollo";
    public bool TieneRiego {get; set; } = false;
    public TimeOnly HorarioSms {get; set; } = new TimeOnly(6, 0); 
}