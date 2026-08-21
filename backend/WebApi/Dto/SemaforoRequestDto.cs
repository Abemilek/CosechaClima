using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class SemaforoRequestDto
{
    [Required]
    public int ParcelaId { get; set; }
}
