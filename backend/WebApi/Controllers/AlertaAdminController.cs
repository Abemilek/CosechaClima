using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Interface;

namespace WebApi.Controllers;

[ApiController]
[Route("api/admin/alertas")]
[Authorize(Roles = "Admin")]
public class AlertaAdminController : ControllerBase
{
    private readonly IAlertaService _alertaService;

    public AlertaAdminController(IAlertaService alertaService)
    {
        _alertaService = alertaService;
    }

    [HttpGet]
    public async Task<IActionResult> ObtenerRecientes([FromQuery] int limite = 100)
    {
        var limiteSeguro = Math.Clamp(limite, 1, 500);
        var alertas = await _alertaService.ObtenerRecientes(limiteSeguro);
        return Ok(alertas);
    }
}
