using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class ParcelaRequestDto
{
    [Required]
    public int CultivoId { get; set; }

    public int? EtapaFenologicaId { get; set; }

    [Required]
    public int TipoSueloId { get; set; }

    [Required]
    public DateTime FechaSiembra { get; set; }

    [Range(0.01, 10000, ErrorMessage = "el area debe ser mayor a 0")]
    public decimal AreaMzs { get; set; }

    [Range(-90, 90, ErrorMessage = "latitud fuera de rango valido")]
    public decimal? Latitud { get; set; }

    [Range(-180, 180, ErrorMessage = "longitud fuera de rango valido")]
    public decimal? Longitud { get; set; }

    [MaxLength(100)]
    public string? Municipio { get; set; }

    [MaxLength(100)]
    public string? Comunidad { get; set; }
}