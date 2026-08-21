using System.Security.Claims;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/clima")]
[Authorize]
public class ClimaController : ControllerBase
{
    private static readonly TimeSpan AntiguedadMaximaDatoHoy = TimeSpan.FromHours(6);

    private readonly IProveedorClimaticoService _proveedorClimaticoService;
    private readonly IParcelaService _parcelaService;
    private readonly IDatosClimaticoService _datosClimaticoService;

    public ClimaController(IProveedorClimaticoService proveedorClimaticoService,
        IParcelaService parcelaService,
        IDatosClimaticoService datosClimaticoService)
    {
        _proveedorClimaticoService = proveedorClimaticoService;
        _parcelaService = parcelaService;
        _datosClimaticoService = datosClimaticoService;
    }

    [HttpPost("actualizar/{parcelaId}")]
    public async Task<IActionResult> ActualizarClima(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {parcelaId}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        if (parcela.Latitud is null || parcela.Longitud is null)
            return BadRequest(new { mensaje = "la parcela no tiene coordenadas registradas" });

        var datoDeHoy = await _datosClimaticoService.ObtenerPorParcelaYFecha(parcelaId, DateTime.Today);
        if (datoDeHoy is not null
            && (DateTime.Now - datoDeHoy.FechaDescarga) <= AntiguedadMaximaDatoHoy)
        {
            return Ok(datoDeHoy);
        }

        var dato = await _proveedorClimaticoService.ObtenerYGuardarDatosActuales(
            parcelaId, parcela.Latitud.Value, parcela.Longitud.Value);

        if (dato is null)
            return StatusCode(503, new { mensaje = "proveedor climatico no disponible y sin datos previos guardados" });

        return Ok(dato);
    }
}