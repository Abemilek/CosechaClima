using System;

namespace CosechaClima.Models;

public class Productor {
    public int Id {get; set; }
    public int UsuarioId {get; set; }
    public string Departamento {get; set; } = "Carazo";
    public string Municipio {get; set; } = string.Empty;
    public string? Comunidad {get; set; }
    public DateTime FechaRegistro {get; set; } = DateTime.Now;
}