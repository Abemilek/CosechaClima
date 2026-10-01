using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class ResumenSemanalAnonimoRequestDto
{
    [Required]
    public int CultivoId { get; set; }

    public int? EtapaFenologicaId { get; set; }

    [Required]
    public int TipoSueloId { get; set; }

    [Required]
    public DateTime FechaSiembra { get; set; }

    [Required]
    [Range(-90, 90)]
    public decimal Latitud { get; set; }

    [Required]
    [Range(-180, 180)]
    public decimal Longitud { get; set; }
}
