using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class ParcelaUpdateRequestDto
{
    [Range(-90, 90, ErrorMessage = "latitud fuera de rango valido")]
    public decimal? Latitud { get; set; }

    [Range(-180, 180, ErrorMessage = "longitud fuera de rango valido")]
    public decimal? Longitud { get; set; }

    [Range(0.01, 99999.99, ErrorMessage = "el area debe estar entre 0.01 y 99999.99 manzanas")]
    public decimal? AreaMzs { get; set; }

    [MaxLength(100)]
    public string? Municipio { get; set; }

    [MaxLength(100)]
    public string? Comunidad { get; set; }
}