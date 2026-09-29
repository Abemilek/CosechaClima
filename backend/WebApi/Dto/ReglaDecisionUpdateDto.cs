using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class ReglaDecisionUpdateDto
{
    [Required, MaxLength(20)]
    public string NivelRiesgo { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion1 { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion2 { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string Accion3 { get; set; } = string.Empty;

    [Required, MaxLength(500)]
    public string DescripcionAlerta { get; set; } = string.Empty;
}

public class ReglaDecisionActivaDto
{
    [Required]
    public bool Activa { get; set; }
}
