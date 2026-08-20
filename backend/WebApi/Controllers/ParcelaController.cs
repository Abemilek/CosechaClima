using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;
using WebApi.Dto;

namespace WebApi.Controllers;

[ApiController]
[Route("api/parcelas")]
[Authorize]
public class ParcelaController : ControllerBase
{
    private readonly IParcelaService _parcelaService;
    private readonly ICatalogoService _catalogoService;

    public ParcelaController(IParcelaService parcelaService, ICatalogoService catalogoService)
    {
        _parcelaService = parcelaService;
        _catalogoService = catalogoService;
    }

    [HttpPost]
    public async Task<IActionResult> Register([FromBody] ParcelaRequestDto datos)
    {
        if (!await _catalogoService.CultivoExiste(datos.CultivoId))
            return BadRequest(new { mensaje = $"el cultivo {datos.CultivoId} no existe" });

        if (!await _catalogoService.TipoSueloExiste(datos.TipoSueloId))
            return BadRequest(new { mensaje = $"el tipo de suelo {datos.TipoSueloId} no existe" });

        if (datos.EtapaFenologicaId is not null
            && !await _catalogoService.EtapaFenologicaExiste(datos.EtapaFenologicaId.Value))
            return BadRequest(new { mensaje = $"la etapa fenologica {datos.EtapaFenologicaId} no existe" });

        var parcela = new Parcela
        {
            UsuarioId = this.ObtenerUsuarioIdActual(),
            CultivoId = datos.CultivoId,
            EtapaFenologicaId = datos.EtapaFenologicaId,
            TipoSueloId = datos.TipoSueloId,
            FechaSiembra = datos.FechaSiembra,
            AreaMzs = datos.AreaMzs,
            Latitud = datos.Latitud,
            Longitud = datos.Longitud,
            Municipio = datos.Municipio,
            Comunidad = datos.Comunidad
        };

        var id = await _parcelaService.Registrar(parcela);
        return Ok(new { id });
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(int id)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        if (parcela is null)
            return NotFound(new { mensaje = $"no existe la parcela {id}" });

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
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
        if (parcela is null)
            return NotFound();

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        if (!await _catalogoService.EtapaFenologicaExiste(etapaId))
            return BadRequest(new { mensaje = $"la etapa fenologica {etapaId} no existe" });

        var updated = await _parcelaService.ActualizarEtapa(id, etapaId);
        return updated ? Ok() : NotFound();
    }

    [HttpDelete("{id}")]
    public async Task<IActionResult> Delete(int id)
    {
        var parcela = await _parcelaService.ObtenerPorId(id);
        if (parcela is null)
            return NotFound();

        if (parcela.UsuarioId != this.ObtenerUsuarioIdActual())
            return Forbid();

        var deleted = await _parcelaService.Eliminar(id);
        return deleted ? Ok() : NotFound();
    }
}