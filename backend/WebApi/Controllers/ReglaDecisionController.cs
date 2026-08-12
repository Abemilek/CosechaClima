using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;
using Microsoft.AspNetCore.Authorization;

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
}