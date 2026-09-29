using System.Linq;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using WebApi.Dto;
using WebApi.Extensions;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/auth")]
public class UsuarioController : ControllerBase
{
    private readonly IUsuarioService _usuarioService;
    private readonly ITokenGenerator _tokenGenerator;
    private readonly IGoogleTokenValidator _googleTokenValidator;

    public UsuarioController(
        IUsuarioService usuarioService,
        ITokenGenerator tokenGenerator,
        IGoogleTokenValidator googleTokenValidator)
    {
        _usuarioService = usuarioService;
        _tokenGenerator = tokenGenerator;
        _googleTokenValidator = googleTokenValidator;
    }

    [EnableRateLimiting("auth")]
    [HttpPost("google")]
    public async Task<ActionResult<LoginResponseDto>> LoginConGoogle([FromBody] GoogleLoginDto datos)
    {
        var datosGoogle = await _googleTokenValidator.ValidarIdToken(datos.IdToken);

        if (datosGoogle is null)
            return Unauthorized(new { mensaje = "no se pudo validar la cuenta de Google" });

        var usuario = await _usuarioService.ObtenerOCrearDesdeGoogle(datosGoogle);

        if (!usuario.Activo)
            return Unauthorized(new { mensaje = "esta cuenta esta desactivada" });

        return Ok(ConstruirRespuesta(usuario));
    }

    [EnableRateLimiting("auth")]
    [HttpPost("register")]
    public async Task<ActionResult<LoginResponseDto>> Register([FromBody] RegisterDto datos)
    {
        var existente = await _usuarioService.ObtenerPorEmail(datos.Email);
        if (existente is not null)
            return Conflict(new { mensaje = "ya existe una cuenta con este correo" });

        var usuario = new Usuario
        {
            Nombre = datos.Nombre,
            Email = datos.Email
        };

        var id = await _usuarioService.RegistrarConEmail(usuario, datos.Password);
        usuario.Id = id;

        return Ok(ConstruirRespuesta(usuario));
    }

    [EnableRateLimiting("auth")]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponseDto>> Login([FromBody] LoginDto datos)
    {
        var usuario = await _usuarioService.AutenticarConEmail(datos.Email, datos.Password);

        if (usuario is null)
            return Unauthorized(new { mensaje = "correo o contrasena incorrectos" });

        return Ok(ConstruirRespuesta(usuario));
    }

    [Authorize(Roles = "Admin")]
    [HttpGet("~/api/admin/usuarios")]
    public async Task<IActionResult> ListarUsuarios()
    {
        var usuarios = await _usuarioService.ListarTodos();
        return Ok(usuarios.Select(u => new UsuarioAdminDto
        {
            Id = u.Id,
            Nombre = u.Nombre,
            Email = u.Email,
            Proveedor = u.Proveedor.ToString(),
            FechaRegistro = u.FechaRegistro,
            Activo = u.Activo,
            EsAdmin = u.EsAdmin
        }));
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("~/api/admin/usuarios/{id:int}/rol")]
    public async Task<IActionResult> CambiarRol(int id, [FromBody] CambiarRolDto datos)
    {
        if (id == this.ObtenerUsuarioIdActual() && !datos.EsAdmin)
            return BadRequest(new { mensaje = "no podes quitarte tu propio rol de administrador" });

        var actualizado = await _usuarioService.CambiarRol(id, datos.EsAdmin);
        return actualizado ? Ok() : NotFound(new { mensaje = $"no existe el usuario {id}" });
    }

    [Authorize(Roles = "Admin")]
    [HttpPut("~/api/admin/usuarios/{id:int}/estado")]
    public async Task<IActionResult> CambiarEstado(int id, [FromBody] CambiarEstadoDto datos)
    {
        if (id == this.ObtenerUsuarioIdActual() && !datos.Activo)
            return BadRequest(new { mensaje = "no podes desactivar tu propia cuenta" });

        var actualizado = await _usuarioService.CambiarActivo(id, datos.Activo);
        return actualizado ? Ok() : NotFound(new { mensaje = $"no existe el usuario {id}" });
    }

    private LoginResponseDto ConstruirRespuesta(Usuario usuario) => new()
    {
        Token = _tokenGenerator.GenerateFor(usuario),
        Nombre = usuario.Nombre,
        Email = usuario.Email,
        FotoUrl = usuario.FotoUrl,
        EsAdmin = usuario.EsAdmin
    };
}
