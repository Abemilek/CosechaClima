using Microsoft.Extensions.Localization;

namespace WebApi.Dto;

// este dto sera lo que se devolvera a la aplicacion
public class SemaforoDto {
    public string NivelRiesgo {get; set; } = string.Empty;
    public string DescripcionAlerta {get; set; } = string.Empty;
    public List<string> Acciones {get; set; } = new();
    // aqui se junta las 3 acciones, pues es mejor darselo asi a la aplicacion
    public DateTime Fecha {get; set; }
}