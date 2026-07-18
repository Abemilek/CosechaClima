using System;

namespace CosechaClima.Models;

public class TipoSuelo {
    public int Id {get; set;}
    public string Nombre {get; set; } = string.Empty;
    public string? Descripcion {get; set; }
}