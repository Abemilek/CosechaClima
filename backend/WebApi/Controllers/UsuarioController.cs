using Microsoft.AspNetCore.Mvc;
using WebApi.Dto;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;
using Microsoft.AspNetCore.RateLimiting;

namespace WebApi.Controllers;

[ApiController]
[Route("api/auth")]
public class UsuarioController : ControllerBase
{
    private readonly IUsuarioService _usuarioService;
    private readonly TokenGenerator _tokenGenerator;

    public UsuarioController(IUsuarioService usuarioService,TokenGenerator tokenGenerator)
    {
        _usuarioService = usuarioService;
        _tokenGenerator = tokenGenerator;
    }

    [EnableRateLimiting("auth")]
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto datos)
    {
        var existente = await _usuarioService.ObtenerPorTelefono(datos.Telefono);
        if (existente != null)
        {
            return Conflict(new { mensaje = "ya existe un usuario con este telefono" });
        }

        var usuario = new Usuario
        {
            Nombre = datos.Nombre,
            Telefono = datos.Telefono
        };

        var id = await _usuarioService.Registrar(usuario, datos.Pin);
        return Ok(new { id, mensaje = "usuario registrado correctamente" });
    }

    [EnableRateLimiting("auth")]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponseDto>> Login([FromBody] LoginDto datos)
    {
        var user = await _usuarioService.Autenticar(datos.Telefono, datos.Pin);
        if (user is null)
            return Unauthorized(new { message = "telefno o pin incorrecto" });

        var token = _tokenGenerator.GenerateFor(user);
        return Ok(new LoginResponseDto { Token = token, Nombre = user.Nombre });
    }
}