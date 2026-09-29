using Microsoft.Extensions.Localization;

namespace WebApi.Dto;

public class SemaforoDto {
    public string NivelRiesgo {get; set; } = string.Empty;
    public string DescripcionAlerta {get; set; } = string.Empty;
    public List<string> Acciones {get; set; } = new();
    public DateTime Fecha {get; set; }
    public int EventoClimaticoId {get; set; }
}