using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;

namespace WebApi.Controllers;

[ApiController]
[Route("api/catalogos")]
[Authorize]
public class CatalogoController : ControllerBase
{
    private readonly ICatalogoService _catalogoService;

    public CatalogoController(ICatalogoService catalogoService)
    {
        _catalogoService = catalogoService;
    }

    [HttpGet("cultivos")]
    public async Task<IActionResult> ObtenerCultivos()
    {
        var cultivos = await _catalogoService.ObtenerCultivos();
        return Ok(cultivos);
    }

    [HttpGet("tipos-suelo")]
    public async Task<IActionResult> ObtenerTiposSuelo()
    {
        var tiposSuelo = await _catalogoService.ObtenerTiposSuelo();
        return Ok(tiposSuelo);
    }

    [HttpGet("eventos-climaticos")]
    public async Task<IActionResult> ObtenerEventosClimaticos()
    {
        var eventos = await _catalogoService.ObtenerEventosClimaticos();
        return Ok(eventos);
    }

    [HttpGet("etapas-fenologicas")]
    public async Task<IActionResult> ObtenerEtapasFenologicas()
    {
        var etapas = await _catalogoService.ObtenerEtapasFenologicas();
        return Ok(etapas);
    }
}