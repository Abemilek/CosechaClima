using Microsoft.AspNetCore.Mvc;
using WebApi.Dto;
using WebApi.Interface;
using WebApi.Models;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using WebApi.Extensions;


namespace WebApi.Controllers;

[ApiController]
[Route("api/motor")]
[Authorize]
public class MotorDecisionesController : ControllerBase
{
    private readonly IMotorDecisionesService _motorDecisionesService;
    private readonly IParcelaService _parcelaService;

    public MotorDecisionesController(IMotorDecisionesService motorDecisionesService, IParcelaService parcelaService)
    {
        _motorDecisionesService = motorDecisionesService;
        _parcelaService = parcelaService;
    }

    [HttpPost("semaforo")]
    public async Task<ActionResult<SemaforoDto>> ObtenerSemaforo([FromBody] SemaforoRequestDto datos)
    {
        var parcela = await _parcelaService.ObtenerPorId(datos.ParcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {datos.ParcelaId}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        try
        {
            var alert = await _motorDecisionesService.CalcularSemaforo(datos.ParcelaId);
            var dto = new SemaforoDto
            {
                NivelRiesgo = alert.NivelRiesgo,
                DescripcionAlerta = alert.DescripcionAlerta,
                Acciones = new List<string> { alert.Accion1, alert.Accion2, alert.Accion3 },
                Fecha = alert.Fecha
            };
            return Ok(dto);
        }
        catch (InvalidOperationException ex)
        {
            return NotFound(new { mensaje = ex.Message });
        }
    }
}