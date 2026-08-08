using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;
using WebApi.Dto;

namespace WebApi.Controllers;

[ApiController]
[Route("api/umbrales")]
[Authorize]
public class UmbralConfiguracionController : ControllerBase
{
    private readonly IUmbralConfiguracionService _umbralService;

    public UmbralConfiguracionController(IUmbralConfiguracionService umbralService)
    {
        _umbralService = umbralService;
    }

    [HttpPost]
    public async Task<IActionResult> CreateOrUpdate([FromBody] UmbralRequestDto datos)
    {
        var umbral = new UmbralConfiguracion
        {
            UsuarioId = this.ObtenerUsuarioIdActual(),
            LluviaIntensaMm = datos.LluviaIntensaMm,
            VientoFuerteKmh = datos.VientoFuerteKmh,
            CaniculaDias = datos.CaniculaDias,
            VariedadCultivo = datos.VariedadCultivo,
            TieneRiego = datos.TieneRiego,
            HorarioSms = datos.HorarioSms
        };

        var id = await _umbralService.CrearOActualizar(umbral);
        return Ok(new { id });
    }

    [HttpGet("mios")]
    public async Task<IActionResult> GetMine()
    {
        var usuarioId = this.ObtenerUsuarioIdActual();
        var umbral = await _umbralService.ObtenerPorUsuario(usuarioId);
        return umbral is null ? NotFound() : Ok(umbral);
    }
}