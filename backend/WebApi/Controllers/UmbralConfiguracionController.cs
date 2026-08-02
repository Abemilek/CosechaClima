using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/umbrales")]
public class UmbralConfiguracionController : ControllerBase
{
    private readonly IUmbralConfiguracionService _umbralService;

    public UmbralConfiguracionController(IUmbralConfiguracionService umbralService)
    {
        _umbralService = umbralService;
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrUpdate([FromBody] UmbralConfiguracion umbral)
    {
        var id = await _umbralService.CrearOActualizar(umbral);
        return Ok(new { id });
    }

    [HttpGet("usuario/{usuarioId}")]
    public async Task<IActionResult> GetByUser(int usuarioId)
    {
        var umbral = await _umbralService.ObtenerPorUsuario(usuarioId);
        return umbral is null ? NotFound() : Ok(umbral);
    }
}