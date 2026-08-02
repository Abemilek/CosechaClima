using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/logs")]
public class BitacoraController : ControllerBase
{
    private readonly IBitacoraService _bitacoraService;

    public BitacoraController(IBitacoraService bitacoraService)
    {
        _bitacoraService = bitacoraService;
    }

    [HttpPost]
    public async Task<IActionResult> RegisterEntry([FromBody] BitacoraCampo entrada)
    {
        var id = await _bitacoraService.RegistrarEntrada(entrada);
        return Ok(new { id });
    }

    [HttpGet("user/{userId}")]
    public async Task<IActionResult> GetHistory(int usuarioId)
    {
        var history = await _bitacoraService.ObtenerHistorial(usuarioId);
        return Ok(history);
    }

    [HttpPut("{entryId}/action/{actionNumber}")]
    public async Task<IActionResult> MarkActionCompleted(int entradaId, int numeroAccion)
    {
        var updated = await _bitacoraService.MarcarAccionCompletada(entradaId, numeroAccion);
        return updated ? Ok() : NotFound();
    }

    [HttpGet("user/{userId}/summary")]
    public async Task<IActionResult> ShareSummary(int usuarioId)
    {
        var summary = await _bitacoraService.CompartirResumen(usuarioId);
        return Ok(new { summary });
    }
}