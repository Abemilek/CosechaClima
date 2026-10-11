using System.Linq;
using Microsoft.AspNetCore.Mvc;
using WebApi.Dto;
using WebApi.Interface;
using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
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
    [EnableRateLimiting("motor")]
    public async Task<ActionResult<SemaforoDto>> ObtenerSemaforo([FromBody] SemaforoRequestDto datos)
    {
        var parcela = await _parcelaService.ObtenerPorId(datos.ParcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {datos.ParcelaId}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var alert = await _motorDecisionesService.CalcularSemaforo(datos.ParcelaId);
        var dto = new SemaforoDto
        {
            NivelRiesgo = alert.NivelRiesgo,
            DescripcionAlerta = alert.DescripcionAlerta,
            Acciones = new List<string> { alert.Accion1, alert.Accion2, alert.Accion3 },
            Fecha = alert.Fecha,
            EventoClimaticoId = alert.EventoClimaticoId
        };
        return Ok(dto);
    }

    [HttpGet("resumen-semanal/{parcelaId:int}")]
    [EnableRateLimiting("motor")]
    public async Task<ActionResult<ResumenSemanalDto>> ObtenerResumenSemanal(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {parcelaId}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var resumen = await _motorDecisionesService.CalcularResumenSemanal(parcelaId);

        return Ok(new ResumenSemanalDto
        {
            Dias = resumen.Dias.Select(d => new DiaResumenSemanalDto
            {
                Fecha = d.Fecha,
                NivelRiesgo = d.NivelRiesgo,
                TemperaturaMax = d.TemperaturaMax,
                TemperaturaMin = d.TemperaturaMin,
                Precipitacion = d.Precipitacion,
            }).ToList(),
            NivelRiesgoMaximo = resumen.NivelRiesgoMaximo,
            DiaMasCritico = resumen.DiaMasCritico,
            DescripcionAlerta = resumen.DescripcionAlerta,
            AccionesDeLaSemana = resumen.AccionesDeLaSemana,
        });
    }
}