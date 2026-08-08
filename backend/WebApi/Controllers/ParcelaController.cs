using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/parcelas")]
[Authorize]
public class ParcelaController : ControllerBase
{
    private readonly IParcelaService _parcelaService;

    public ParcelaController(IParcelaService parcelaService)
    {
        _parcelaService = parcelaService;
    }

    [HttpPost]
    public async Task<IActionResult> Register([FromBody] Parcela parcela)
    {
        parcela.UsuarioId = this.ObtenerUsuarioIdActual();
        var id = await _parcelaService.Registrar(parcela);
        return Ok(new { id });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        if (parcela is null || parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        return Ok(parcela);
    }

    [HttpGet("mias")]
    public async Task<IActionResult> GetMine()
    {
        var usuarioId = this.ObtenerUsuarioIdActual();
        var parcelas = await _parcelaService.ObtenerPorUsuario(usuarioId);
        return Ok(parcelas);
    }

    [HttpPut("{id}/etapa/{etapaId}")]
    public async Task<IActionResult> ActualizarEtapa(int id, int etapaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        if (parcela is null || parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var updated = await _parcelaService.ActualizarEtapa(id, etapaId);
        return updated ? Ok() : NotFound();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        if (parcela is null || parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var deleted = await _parcelaService.Eliminar(id);
        return deleted ? Ok() : NotFound();
    }
}