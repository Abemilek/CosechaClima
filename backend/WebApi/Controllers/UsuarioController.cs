using Microsoft.AspNetCore.Mvc;
using WebApi.Dto;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;

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

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto datos)
    {
        var existingUser = await _usuarioService.ObtenerPorTelefono(datos.Telefono);
        if (existingUser is not null)
            return Conflict(new { mensaje = "el numero de telefono ya esta registrado" });

        var usuario = new Usuario
        {
            Nombre = datos.Nombre,
            Telefono = datos.Telefono,
            PinHash = datos.Pin
        };

        var id = await _usuarioService.Registrar(usuario);
        return Ok(new { id, mensaje = "Usuario registrado correctamente" });
    }

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