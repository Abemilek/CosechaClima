using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using WebApi.Dto;
using WebApi.Extensions;
using WebApi.Implementation;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/alertas")]
[Authorize]
public class AlertaController : ControllerBase
{
    private readonly IAlertaService _alertaService;
    private readonly IParcelaService _parcelaService;
    private readonly IReglaDecisionService _reglaService;
    private readonly IEtapaFenologicaService _etapaService;
    private readonly ICatalogoService _catalogoService;

    public AlertaController(
        IAlertaService alertaService,
        IParcelaService parcelaService,
        IReglaDecisionService reglaService,
        IEtapaFenologicaService etapaService,
        ICatalogoService catalogoService)
    {
        _alertaService = alertaService;
        _parcelaService = parcelaService;
        _reglaService = reglaService;
        _etapaService = etapaService;
        _catalogoService = catalogoService;
    }

    /// <summary>
    /// La app (que calcula el semaforo en el dispositivo) reporta el evento detectado para una parcela.
    /// Idempotente por (parcela, fecha). Alimenta la auditoria del Admin Console.
    /// </summary>
    [HttpPut("parcela/{parcelaId:int}")]
    [EnableRateLimiting("motor")]
    public async Task<IActionResult> Reportar(int parcelaId, [FromBody] AlertaReporteDto datos)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {parcelaId}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var hoy = FechasUtc.HoyNicaragua();
        var fecha = datos.Fecha.Date;
        if (Math.Abs((fecha - hoy).TotalDays) > 2)
            return BadRequest(new { mensaje = "la fecha de la alerta esta fuera del rango permitido" });

        var eventos = await _catalogoService.ObtenerEventosClimaticos();
        if (eventos.All(e => e.Id != datos.EventoClimaticoId))
            return BadRequest(new { mensaje = $"el evento climatico {datos.EventoClimaticoId} no existe" });

        var etapaId = parcela.EtapaFenologicaId
            ?? (await _etapaService.CalcularDesdeFecha(parcela.FechaSiembra)).Id;

        var regla = await _reglaService.ObtenerPorClave(
            datos.EventoClimaticoId, parcela.CultivoId, etapaId, parcela.TipoSueloId);

        if (regla is null)
            return NotFound(new { mensaje = "no hay una regla activa para esa combinacion" });

        var id = await _alertaService.GuardarOActualizar(new Alerta
        {
            UsuarioId = parcela.UsuarioId,
            ParcelaId = parcelaId,
            Fecha = fecha,
            EventoClimaticoId = regla.EventoClimaticoId,
            NivelRiesgo = regla.NivelRiesgo,
            Accion1 = regla.Accion1,
            Accion2 = regla.Accion2,
            Accion3 = regla.Accion3,
            DescripcionAlerta = regla.DescripcionAlerta
        });

        return Ok(new { id });
    }
}
