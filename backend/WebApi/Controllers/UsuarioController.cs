using System.Linq;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using WebApi.Dto;
using WebApi.Extensions;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Controllers;

[ApiController]
[Route("api/auth")]
[ResponseCache(NoStore = true, Location = ResponseCacheLocation.None)]
public class UsuarioController : ControllerBase
{
    private const string CookieRefresh = "cc_refresh";
    private const string RutaCookieWeb = "/api/auth/web";
    private const string CabeceraCsrf = "X-Requested-With";
    private const string ValorCsrf = "cosechaclima-admin";

    private readonly IUsuarioService _usuarioService;
    private readonly ITokenGenerator _tokenGenerator;
    private readonly IGoogleTokenValidator _googleTokenValidator;
    private readonly IRefreshTokenService _refreshTokenService;
    private readonly IConfiguration _configuration;

    public UsuarioController(
        IUsuarioService usuarioService,
        ITokenGenerator tokenGenerator,
        IGoogleTokenValidator googleTokenValidator,
        IRefreshTokenService refreshTokenService,
        IConfiguration configuration)
    {
        _usuarioService = usuarioService;
        _tokenGenerator = tokenGenerator;
        _googleTokenValidator = googleTokenValidator;
        _refreshTokenService = refreshTokenService;
        _configuration = configuration;
    }

    // ---------------------------------------------------------------- movil (refresh token en el cuerpo)

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

        var refresh = await _refreshTokenService.EmitirAsync(usuario.Id, "movil");
        return Ok(ConstruirRespuesta(usuario, refresh));
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

        var refresh = await _refreshTokenService.EmitirAsync(usuario.Id, "movil");
        return Ok(ConstruirRespuesta(usuario, refresh));
    }

    [EnableRateLimiting("auth")]
    [HttpPost("login")]
    public async Task<ActionResult<LoginResponseDto>> Login([FromBody] LoginDto datos)
    {
        var usuario = await _usuarioService.AutenticarConEmail(datos.Email, datos.Password);

        if (usuario is null)
            return Unauthorized(new { mensaje = "correo o contrasena incorrectos" });

        var refresh = await _refreshTokenService.EmitirAsync(usuario.Id, "movil");
        return Ok(ConstruirRespuesta(usuario, refresh));
    }

    /// <summary>Canjea un refresh token por un access token nuevo y un refresh token nuevo (rotacion).</summary>
    [EnableRateLimiting("refresh")]
    [HttpPost("refresh")]
    public async Task<ActionResult<LoginResponseDto>> Refrescar([FromBody] RefreshDto datos)
    {
        var rotacion = await _refreshTokenService.RotarAsync(datos.RefreshToken);
        if (rotacion is null || rotacion.Cliente != "movil")
            return Unauthorized(new { mensaje = "la sesion ya no es valida, inicia sesion de nuevo" });

        var usuario = await _usuarioService.ObtenerPorId(rotacion.UsuarioId);
        if (usuario is null || !usuario.Activo)
            return Unauthorized(new { mensaje = "la sesion ya no es valida, inicia sesion de nuevo" });

        return Ok(ConstruirRespuesta(usuario, rotacion.NuevoToken));
    }

    [EnableRateLimiting("refresh")]
    [HttpPost("logout")]
    public async Task<IActionResult> CerrarSesion([FromBody] RefreshDto datos)
    {
        await _refreshTokenService.RevocarFamiliaAsync(datos.RefreshToken);
        return NoContent();
    }

    // ------------------------------------------------- panel web (refresh token en cookie HttpOnly)

    [EnableRateLimiting("auth")]
    [HttpPost("web/login")]
    public async Task<ActionResult<LoginResponseDto>> LoginWeb([FromBody] LoginDto datos)
    {
        var usuario = await _usuarioService.AutenticarConEmail(datos.Email, datos.Password);

        if (usuario is null)
            return Unauthorized(new { mensaje = "correo o contrasena incorrectos" });

        if (!usuario.EsAdmin)
            return StatusCode(StatusCodes.Status403Forbidden,
                new { mensaje = "esta cuenta no tiene permisos de administrador" });

        var refresh = await _refreshTokenService.EmitirAsync(usuario.Id, "web");
        EscribirCookieRefresh(refresh);
        return Ok(ConstruirRespuesta(usuario, null));
    }

    [EnableRateLimiting("refresh")]
    [HttpPost("web/refresh")]
    public async Task<ActionResult<LoginResponseDto>> RefrescarWeb()
    {
        // Defensa CSRF: un formulario cruzado no puede fijar cabeceras personalizadas y
        // un fetch cruzado exige preflight CORS (solo pasan los origenes permitidos).
        if (!CsrfValido())
            return BadRequest(new { mensaje = "solicitud no permitida" });

        if (!Request.Cookies.TryGetValue(CookieRefresh, out var token) || string.IsNullOrEmpty(token))
            return Unauthorized(new { mensaje = "no hay una sesion activa" });

        var rotacion = await _refreshTokenService.RotarAsync(token);
        if (rotacion is null || rotacion.Cliente != "web")
        {
            BorrarCookieRefresh();
            return Unauthorized(new { mensaje = "la sesion expiro, inicia sesion de nuevo" });
        }

        var usuario = await _usuarioService.ObtenerPorId(rotacion.UsuarioId);
        if (usuario is null || !usuario.Activo || !usuario.EsAdmin)
        {
            await _refreshTokenService.RevocarFamiliaAsync(rotacion.NuevoToken);
            BorrarCookieRefresh();
            return Unauthorized(new { mensaje = "la sesion expiro, inicia sesion de nuevo" });
        }

        EscribirCookieRefresh(rotacion.NuevoToken);
        return Ok(ConstruirRespuesta(usuario, null));
    }

    [HttpPost("web/logout")]
    public async Task<IActionResult> CerrarSesionWeb()
    {
        if (!CsrfValido())
            return BadRequest(new { mensaje = "solicitud no permitida" });

        if (Request.Cookies.TryGetValue(CookieRefresh, out var token) && !string.IsNullOrEmpty(token))
            await _refreshTokenService.RevocarFamiliaAsync(token);

        BorrarCookieRefresh();
        return NoContent();
    }

    // -------------------------------------------------------------------------------------- admin

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

    // ------------------------------------------------------------------------------------ helpers

    private LoginResponseDto ConstruirRespuesta(Usuario usuario, string? refreshToken)
    {
        var minutos = int.TryParse(_configuration["Jwt:DurationMinutes"], out var m) && m > 0
            ? m
            : TokenGenerator.DuracionPorDefectoMinutos;

        return new LoginResponseDto
        {
            Token = _tokenGenerator.GenerateFor(usuario),
            RefreshToken = refreshToken,
            ExpiraEnSegundos = minutos * 60,
            Nombre = usuario.Nombre,
            Email = usuario.Email,
            FotoUrl = usuario.FotoUrl,
            EsAdmin = usuario.EsAdmin
        };
    }

    private bool CsrfValido() =>
        Request.Headers.TryGetValue(CabeceraCsrf, out var valor) && valor == ValorCsrf;

    private CookieOptions OpcionesCookie() => new()
    {
        HttpOnly = true,
        // En produccion siempre Secure. Solo se puede desactivar (Auth:CookieSecure=false) para
        // desarrollo local por http.
        Secure = _configuration.GetValue("Auth:CookieSecure", true),
        SameSite = SameSiteMode.Strict,
        Path = RutaCookieWeb,
        IsEssential = true
    };

    private void EscribirCookieRefresh(string token)
    {
        var opciones = OpcionesCookie();
        var dias = _configuration.GetValue("Jwt:RefreshDays", 30);
        opciones.MaxAge = TimeSpan.FromDays(dias > 0 ? dias : 30);
        Response.Cookies.Append(CookieRefresh, token, opciones);
    }

    private void BorrarCookieRefresh() => Response.Cookies.Delete(CookieRefresh, OpcionesCookie());
}
