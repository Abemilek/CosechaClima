using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;

namespace WebApi.Controllers;

[ApiController]
[Route("api/clima")]
public class ClimaController : ControllerBase
{
    private readonly INasaPowerService _nasaPowerService;
    private readonly IParcelaService _parcelaService;

    public ClimaController(INasaPowerService nasaPowerService, IParcelaService parcelaService)
    {
        _nasaPowerService = nasaPowerService;
        _parcelaService = parcelaService;
    }

    [HttpPost("actualizar/{parcelaId}")]
    public async Task<IActionResult> ActualizarClima(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"No existe la parcela {parcelaId}" });

        if (parcela.Latitud is null || parcela.Longitud is null)
            return BadRequest(new { mensaje = "La parcela no tiene coordenadas registradas" });

        var dato = await _nasaPowerService.ObtenerYGuardarDatosActuales(
            parcelaId, parcela.Latitud.Value, parcela.Longitud.Value);

        if (dato is null)
            return StatusCode(503, new { mensaje = "NASA POWER no disponible y sin datos previos guardaddos" });

        return Ok(dato);
    }
}