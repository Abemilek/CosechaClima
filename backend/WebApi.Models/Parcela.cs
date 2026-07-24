namespace WebApi.Models;

public class Parcela {
    public int Id { get; set; }
    public int UsuarioId { get; set; }
    public int CultivoId { get; set; }
    public int? EtapaFenologicaId { get; set; }
    public int TipoSueloId { get; set; }
    public DateTime FechaSiembra { get; set; } = DateTime.Now;
    public decimal AreaMzs { get; set; }
    public decimal? Latitud { get; set; }
    public decimal? Longitud { get; set; }
    public string? Municipio { get; set; }
    public string? Comunidad { get; set; }
    public DateTime FechaRegistro { get; set; } = DateTime.Now;
    public bool Activa { get; set; } = true;
}
