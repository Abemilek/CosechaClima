namespace WebApi.Models;

public class AccionRecomendada {
    public int Id {get; set; }
    public int AlertaId {get; set; }
    public int NumeroAccion {get; set; }
    public string Descripcion {get; set; } = string.Empty;
    public bool Completada {get; set; } = false;
}
