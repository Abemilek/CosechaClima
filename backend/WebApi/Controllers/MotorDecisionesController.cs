using Microsoft.AspNetCore.Mvc;
using WebApi.Dto;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/motor")]
public class MotorDecisionesController : ControllerBase
{
    private readonly IMotorDecisionesService _motorDecisionesService;

    public MotorDecisionesController(IMotorDecisionesService motorDecisionesService)
    {
        _motorDecisionesService = motorDecisionesService;
    }

    [HttpGet("Semaforo")]
    public async Task<ActionResult<SemaforoDto>> ObtenerSemaforo ([FromQuery] int parcelaId)
    {
        try
        {
            var alert = await _motorDecisionesService.CalcularSemaforo(parcelaId);

            var dto = new SemaforoDto
            {
                NivelRiesgo = alert.NivelRiesgo,
                DescripcionAlerta = alert.DescripcionAlerta,
                Acciones = new List<string> {alert.Accion1, alert.Accion2, alert.Accion3},
                Fecha = alert.Fecha
            };
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new {mensaje = ex.Message});
        }
    }
}