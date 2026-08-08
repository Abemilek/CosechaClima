using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class UmbralRequestDto
{
    [Range(0, 1000)]
    public int LluviaIntensaMm { get; set; } = 100;

    [Range(0, 300)]
    public int VientoFuerteKmh { get; set; } = 40;

    [Range(1, 60)]
    public int CaniculaDias { get; set; } = 7;

    [MaxLength(50)]
    public string VariedadCultivo { get; set; } = "Criollo";

    public bool TieneRiego { get; set; }

    [Required]
    public TimeOnly HorarioSms { get; set; }
}