using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using WebApi.Dto;
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

    private LoginResponseDto ConstruirRespuesta(Usuario usuario) => new()
    {
        Token = _tokenGenerator.GenerateFor(usuario),
        Nombre = usuario.Nombre,
        Email = usuario.Email,
        FotoUrl = usuario.FotoUrl,
        EsAdmin = usuario.EsAdmin
    };
}
