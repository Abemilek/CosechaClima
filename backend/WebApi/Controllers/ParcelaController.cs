using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/parcelas")]
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
        var id = await _parcelaService.Registrar(parcela);
        return Ok(new { id });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        return Ok(parcela);
    }

    [HttpGet("usuario/{usuarioId}")]
    public async Task<IActionResult> GetByUser(int usuarioId)
    {
        var parcelas = await _parcelaService.ObtenerPorUsuario(usuarioId);
        return Ok(parcelas);
    }

    [HttpPut("{id}/etapa/{etapaId}")]
    public async Task<IActionResult> ActualizarEtapa(int id, int etapaId)
    {
        var updated = await _parcelaService.ActualizarEtapa(id, etapaId);
        return updated ? Ok() : NotFound();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var deleted = await _parcelaService.Eliminar(id);
        return deleted ? Ok() : NotFound();
    }
}