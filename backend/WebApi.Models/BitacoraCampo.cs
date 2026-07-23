namespace WebApi.Models;

public class BitacoraCampo {
    public int Id {get; set; }
    public int AlertaId {get; set; }
    public int AccionId {get; set; }
    public DateTime FechaCompletado {get; set; } = DateTime.Now;
    public string? Notas {get; set; }
}
