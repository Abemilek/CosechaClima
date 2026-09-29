using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;
using Microsoft.AspNetCore.Authorization;
using WebApi.Dto;

namespace WebApi.Controllers;

[ApiController]
[Route("api/reglas")]
[Authorize]
public class ReglaDecisionController : ControllerBase
{
    private readonly IReglaDecisionService _reglaDecisionService;

    public ReglaDecisionController(IReglaDecisionService reglaDecisionService)
    {
        _reglaDecisionService = reglaDecisionService;
    }

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ObtenerTodas()
    {
        var reglas = await _reglaDecisionService.ObtenerTodas();
        return Ok(reglas);
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("sembrar")]
    public async Task<IActionResult> Sembrar()
    {
        await _reglaDecisionService.SembrarReglasIniciales();
        return Ok(new { mensaje = "reglas placeholder generadas o ya existian"});
    }

    [Authorize(Roles = "Admin")]
    [HttpPost("aplicar-contenido-preliminar")]
    public async Task<IActionResult> AplicarContenidoPreliminar()
    {
        await _reglaDecisionService.AplicarContenidoPreliminar();
        return Ok(new {message = "contenido preliminar aplicado reglas representativas"});
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{id:int}")]
    public async Task<IActionResult> Actualizar(int id, [FromBody] ReglaDecisionUpdateDto datos)
    {
        var existente = await _reglaDecisionService.ObtenerPorId(id);
        if (existente is null)
            return NotFound(new { mensaje = $"no existe la regla {id}" });

        var actualizado = await _reglaDecisionService.ActualizarContenido(
            id, datos.NivelRiesgo, datos.Accion1, datos.Accion2, datos.Accion3, datos.DescripcionAlerta);

        return actualizado ? Ok() : NotFound();
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("{id:int}/activa")]
    public async Task<IActionResult> CambiarActiva(int id, [FromBody] ReglaDecisionActivaDto datos)
    {
        var actualizado = await _reglaDecisionService.CambiarActiva(id, datos.Activa);
        return actualizado ? Ok() : NotFound(new { mensaje = $"no existe la regla {id}" });
    }
}