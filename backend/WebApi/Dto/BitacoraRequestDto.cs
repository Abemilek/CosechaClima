using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class BitacoraRequestDto
{
    [Required]
    public int ParcelaId { get; set; }

    [Required]
    public DateTime Fecha { get; set; }

    [Required]
    public int EventoClimaticoId { get; set; }

    [Required, MaxLength(20)]
    public string NivelRiesgo { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion1Texto { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion2Texto { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion3Texto { get; set; } = string.Empty;

    [MaxLength(2000)]
    public string? Notas { get; set; }
}