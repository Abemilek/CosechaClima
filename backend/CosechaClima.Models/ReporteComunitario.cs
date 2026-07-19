using System;

namespace CosechaClima.Models;

public class ReporteComunitario {
    public int Id {get; set; }
    public int UsuarioId {get; set; }
    public string Municipio {get; set; } = string.Empty;
    public string Sintomas {get; set; } = string.Empty;
    public DateTime FechaReporte {get; set; } = DateTime.Now;
    public decimal? Latitud {get; set; }
    public decimal? Longitud {get; set;}
 }