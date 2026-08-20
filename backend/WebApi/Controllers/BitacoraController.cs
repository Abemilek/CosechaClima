using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;
using WebApi.Dto;

namespace WebApi.Controllers;

[ApiController]
[Route("api/logs")]
[Authorize]
public class BitacoraController : ControllerBase
{
    private readonly IBitacoraService _bitacoraService;
    private readonly IParcelaService _parcelaService;

    public BitacoraController(IBitacoraService bitacoraService, IParcelaService parcelaService)
    {
        _bitacoraService = bitacoraService;
        _parcelaService = parcelaService;
    }

    [HttpPost]
    public async Task<IActionResult> RegisterEntry([FromBody] BitacoraRequestDto datos)
    {
        var usuarioId = this.ObtenerUsuarioIdActual();

        var parcela = await _parcelaService.ObtenerPorId(datos.ParcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {datos.ParcelaId}" });

        if (parcela.UsuarioId != usuarioId)
            return Forbid();

        var entrada = new BitacoraCampo
        {
            UsuarioId = usuarioId,
            ParcelaId = datos.ParcelaId,
            Fecha = datos.Fecha,
            EventoClimaticoId = datos.EventoClimaticoId,
            NivelRiesgo = datos.NivelRiesgo,
            Accion1Texto = datos.Accion1Texto,
            Accion2Texto = datos.Accion2Texto,
            Accion3Texto = datos.Accion3Texto,
            Notas = datos.Notas
        };

        var id = await _bitacoraService.RegistrarEntrada(entrada);
        return Ok(new { id });
    }

    [HttpGet("mias")]
    public async Task<IActionResult> GetHistory()
    {
        var usuarioId = this.ObtenerUsuarioIdActual();
        var history = await _bitacoraService.ObtenerHistorial(usuarioId);
        return Ok(history);
    }

    [HttpPut("{entradaId}/action/{numeroAccion}")]
    public async Task<IActionResult> MarkActionCompleted(int entradaId, int numeroAccion)
    {
        var usuarioId = this.ObtenerUsuarioIdActual();

        var entrada = await _bitacoraService.ObtenerPorId(entradaId);
        if (entrada is null || entrada.UsuarioId != usuarioId)
            return Forbid();

        var updated = await _bitacoraService.MarcarAccionCompletada(entradaId, numeroAccion);
        return updated ? Ok() : NotFound();
    }

    [HttpGet("mias/summary")]
    public async Task<IActionResult> ShareSummary()
    {
        var usuarioId = this.ObtenerUsuarioIdActual();
        var summary = await _bitacoraService.CompartirResumen(usuarioId);
        return Ok(new { summary });
    }
}