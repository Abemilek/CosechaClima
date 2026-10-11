using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Implementation;
using System.Text;
using System.Text.RegularExpressions;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using WebApi.Implementation.Security;
using WebApi;
using Microsoft.AspNetCore.RateLimiting;
using System.Threading.RateLimiting;
using WebApi.Models;
using Microsoft.AspNetCore.HttpOverrides;
using System.Net;

var builder = WebApplication.CreateBuilder(args);

// La API solo recibe JSON pequeño: 256 KB evita cuerpos enormes (el limite por defecto es ~30 MB).
builder.WebHost.ConfigureKestrel(o => o.Limits.MaxRequestBodySize = 256 * 1024);

builder.Services.AddControllers();
builder.Services.AddMemoryCache();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(opciones =>
{
    opciones.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Description = "pega el token asi: Bearer {token}",
        Name = "Authorization",
        In = ParameterLocation.Header,
        Type = SecuritySchemeType.Http,
        Scheme = "Bearer",
        BearerFormat = "JWT"
    });

    opciones.AddSecurityRequirement(documento => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer", documento)] = []
    });
});

builder.Services.AddCors(opciones =>
{
    opciones.AddPolicy("FrontendPolicy", politica =>
    {
        var origenesPermitidos = (builder.Configuration
            .GetSection("Cors:AllowedOrigins")
            .Get<string[]>() ?? [])
            .Where(o => !string.IsNullOrWhiteSpace(o))
            .ToArray();

        // AllowCredentials hace falta para que el Admin Console envie la cookie HttpOnly del refresh token.
        // Exige origenes explicitos (nunca "*"), que es justo lo que se configura aqui.
        politica.WithOrigins(origenesPermitidos)
            .AllowAnyHeader()
            .AllowAnyMethod()
            .AllowCredentials();
    });
});

var jwtConfig = builder.Configuration.GetSection("Jwt");
var secretKey = jwtConfig["SecretKey"];

const string claveDeRelleno = "pon-aqui-una-clave-secreta-y-larga-minimo-32-caracteres";

if (string.IsNullOrWhiteSpace(secretKey))
{
    throw new InvalidOperationException(
        "Jwt:SecretKey no esta configurada. Defini la variable de entorno " +
        "JWT_SECRET_KEY antes de levantar la API (ver .env.example).");
}

if (secretKey == claveDeRelleno)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey todavia tiene el valor de relleno de .env.example. " +
        "Generá una clave real, por ejemplo con: openssl rand -base64 48");
}

if (Encoding.UTF8.GetByteCount(secretKey) < 32)
{
    throw new InvalidOperationException(
        "Jwt:SecretKey es demasiado corta: HMAC-SHA256 requiere al menos " +
        "32 bytes (256 bits). Generá una con: openssl rand -base64 48");
}

// ---- Detras de un proxy / balanceador ---------------------------------------------------------
// Solo se procesan X-Forwarded-For/Proto si se declara de quien confiar (Proxy:KnownProxies o
// Proxy:KnownNetworks). Sin esa lista se ignoran: asi un cliente no puede falsear su IP para
// esquivar el rate limiting. Con proxy y sin esta configuracion, RemoteIpAddress seria la IP del
// proxy y el limite por IP se volveria global.
var proxiesConfiados = builder.Configuration.GetSection("Proxy:KnownProxies").Get<string[]>() ?? [];
var redesConfiadas = builder.Configuration.GetSection("Proxy:KnownNetworks").Get<string[]>() ?? [];
var reenvioHabilitado = proxiesConfiados.Any(p => !string.IsNullOrWhiteSpace(p))
    || redesConfiadas.Any(r => !string.IsNullOrWhiteSpace(r));

if (reenvioHabilitado)
{
    builder.Services.Configure<ForwardedHeadersOptions>(opciones =>
    {
        opciones.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        opciones.ForwardLimit = 1;
        opciones.KnownProxies.Clear();
        opciones.KnownIPNetworks.Clear();

        foreach (var ip in proxiesConfiados.Where(p => !string.IsNullOrWhiteSpace(p)))
            opciones.KnownProxies.Add(IPAddress.Parse(ip.Trim()));

        foreach (var red in redesConfiadas.Where(r => !string.IsNullOrWhiteSpace(r)))
            opciones.KnownIPNetworks.Add(System.Net.IPNetwork.Parse(red.Trim()));
    });
}

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtConfig["Issuer"],
            ValidAudience = jwtConfig["Audience"],
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey)),
            // Por defecto .NET tolera 5 minutos de desfase, que con tokens de 15 min seria un 33% extra de vida.
            ClockSkew = TimeSpan.FromSeconds(30),
            ValidAlgorithms = [SecurityAlgorithms.HmacSha256]
        };
    });


builder.Services.AddHttpClient<IProveedorClimaticoService, OpenMeteoService>(cliente =>
{
    cliente.BaseAddress = new Uri("https://api.open-meteo.com/v1/forecast");
    cliente.Timeout = TimeSpan.FromSeconds(10);
});

builder.Services.AddSingleton<ConnectionBD>();
builder.Services.AddSingleton<MigradorBD>();

builder.Services.AddScoped<IUsuarioService, UsuarioService>();
builder.Services.AddScoped<IParcelaService, ParcelaService>();
builder.Services.AddScoped<IUmbralConfiguracionService, UmbralConfiguracionService>();
builder.Services.AddScoped<IDatosClimaticoService, DatosClimaticoService>();
builder.Services.AddScoped<IAlertaService, AlertaService>();
builder.Services.AddScoped<IBitacoraService, BitacoraService>();
builder.Services.AddScoped<IMotorDecisionesService, MotorDecisionesService>();
builder.Services.AddScoped<IReglaDecisionService, ReglaDecisionService>();
builder.Services.AddScoped<IEtapaFenologicaService, EtapaFenologicaService>();
builder.Services.AddScoped<ICatalogoService, CatalogoService>();
builder.Services.AddAuthorization();
builder.Services.AddScoped<ITokenGenerator, TokenGenerator>();
builder.Services.AddScoped<IRefreshTokenService, RefreshTokenService>();
builder.Services.AddHostedService<LimpiezaRefreshTokensWorker>();
builder.Services.AddScoped<IGoogleTokenValidator, GoogleTokenValidator>();
builder.Services.AddExceptionHandler<ManejadorErroresGlobal>();
builder.Services.AddProblemDetails();

builder.Services.AddHealthChecks()
    .AddCheck<ChequeoBaseDeDatos>("base-de-datos");

builder.Services.AddRateLimiter(opciones =>
{
    opciones.AddPolicy("auth", contexto =>
    {
        var direccionIp = contexto.Connection.RemoteIpAddress?.ToString() ?? "ip-desconocida";

        return RateLimitPartition.GetSlidingWindowLimiter(direccionIp, _ =>
            new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 2,
                QueueLimit = 0
            });
    });

    // Renovacion de sesion: mas holgada que "auth" (login) porque ocurre en segundo plano y,
    // en zonas rurales, varias personas pueden salir por la misma IP (NAT del operador).
    opciones.AddPolicy("refresh", contexto =>
    {
        var direccionIp = contexto.Connection.RemoteIpAddress?.ToString() ?? "ip-desconocida";

        return RateLimitPartition.GetSlidingWindowLimiter(direccionIp, _ =>
            new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 2,
                QueueLimit = 0
            });
    });

    // Endpoints publicos de solo lectura (paquete de reglas).
    opciones.AddPolicy("publico", contexto =>
    {
        var direccionIp = contexto.Connection.RemoteIpAddress?.ToString() ?? "ip-desconocida";

        return RateLimitPartition.GetSlidingWindowLimiter(direccionIp, _ =>
            new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 2,
                QueueLimit = 0
            });
    });

    opciones.AddPolicy("motor", contexto =>
    {
        var usuarioId = contexto.User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value
            ?? contexto.Connection.RemoteIpAddress?.ToString()
            ?? "usuario-desconocido";

        return RateLimitPartition.GetSlidingWindowLimiter(usuarioId, _ =>
            new SlidingWindowRateLimiterOptions
            {
                PermitLimit = 30,
                Window = TimeSpan.FromMinutes(1),
                SegmentsPerWindow = 2,
                QueueLimit = 0
            });
    });

    opciones.OnRejected = async (contexto, cancellationToken) =>
    {
        contexto.HttpContext.Response.StatusCode = StatusCodes.Status429TooManyRequests;
        await contexto.HttpContext.Response.WriteAsJsonAsync(new
        {
            mensaje = "demasiados intentos, espera un minuto antes de volver a intentar"
        }, cancellationToken);
    };
});

var app = builder.Build();

// Debe ir lo primero: reescribe RemoteIpAddress/Scheme antes de HTTPS redirect y rate limiting.
if (reenvioHabilitado)
{
    app.UseForwardedHeaders();
}
else
{
    app.Logger.LogInformation(
        "Proxy:KnownProxies / Proxy:KnownNetworks vacios: se ignoran las cabeceras X-Forwarded-*. " +
        "Si la API corre detras de un proxy, declara su IP o red (ver .env.example).");
}

app.UseExceptionHandler();

app.Use(async (contexto, siguiente) =>
{
    var cabeceras = contexto.Response.Headers;
    cabeceras["X-Content-Type-Options"] = "nosniff";
    cabeceras["Referrer-Policy"] = "no-referrer";
    cabeceras["X-Frame-Options"] = "DENY";
    await siguiente();
});

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapHealthChecks("/health");

if (!app.Environment.IsDevelopment())
{
    app.UseHsts();
    app.UseHttpsRedirection();
}

app.UseCors("FrontendPolicy");

app.UseAuthentication();

app.UseAuthorization();

app.UseRateLimiter();

app.MapControllers();

// El esquema se crea/actualiza solo, antes de atender peticiones. Si falla, la API no arranca:
// seguir sin esquema solo produciria errores confusos mas adelante.
using (var scopeMigraciones = app.Services.CreateScope())
{
    var migrador = scopeMigraciones.ServiceProvider.GetRequiredService<MigradorBD>();
    await migrador.AplicarPendientesAsync();
    app.Logger.LogInformation("Migraciones de base de datos verificadas");
}

if (int.TryParse(builder.Configuration["Jwt:DurationMinutes"], out var minutosJwt) && minutosJwt > 60)
{
    app.Logger.LogWarning(
        "Jwt:DurationMinutes = {Minutos}: un access token tan largo anula la ventaja de la rotacion de " +
        "refresh tokens. Recomendado: 15.", minutosJwt);
}

using (var scope = app.Services.CreateScope())
{
    try
    {
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var emailAdmin = config["AdminSeed:Email"];
        var passwordAdmin = config["AdminSeed:Password"];

        var emailValido = !string.IsNullOrWhiteSpace(emailAdmin)
            && Regex.IsMatch(emailAdmin, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");

        if (string.IsNullOrWhiteSpace(emailAdmin))
        {
            app.Logger.LogWarning(
                "ADMIN_SEED_EMAIL no esta configurado -- no se crea ningun admin automaticamente. " +
                "Definilo en el .env y reinicia, o asigna el rol manualmente en la base de datos.");
        }
        else if (!emailValido)
        {
            app.Logger.LogWarning(
                "ADMIN_SEED_EMAIL tiene un formato invalido -- se omite el seed del admin");
        }
        else
        {
            var passwordInsegura = string.IsNullOrWhiteSpace(passwordAdmin)
                || passwordAdmin.Length < 8
                || passwordAdmin.Equals("CAMBIAME", StringComparison.OrdinalIgnoreCase)
                || passwordAdmin.Equals("password", StringComparison.OrdinalIgnoreCase);

            var passwordFinal = passwordAdmin;

            if (passwordInsegura)
            {
                passwordFinal = GenerarPasswordSegura();
            }

            var usuarioService = scope.ServiceProvider.GetRequiredService<IUsuarioService>();
            var existente = await usuarioService.ObtenerPorEmail(emailAdmin!);

            if (existente is null)
            {
                var nombreAdmin = config["AdminSeed:Nombre"] ?? "Admin";
                var id = await usuarioService.RegistrarConEmail(
                    new Usuario { Nombre = nombreAdmin, Email = emailAdmin! }, passwordFinal!);
                await usuarioService.MarcarComoAdmin(id);

                if (passwordInsegura)
                {
                    app.Logger.LogWarning(
                        "Admin inicial creado exitosamente -- ADMIN_SEED_PASSWORD no estaba definida " +
                        "(o era insegura). Se genero una clave temporal y debe ser cambiada de inmediato.");
                }
                else
                {
                    app.Logger.LogInformation("Admin inicial creado exitosamente.");
                }
            }
            else if (!existente.EsAdmin)
            {
                await usuarioService.MarcarComoAdmin(existente.Id);
                app.Logger.LogInformation("Rol Admin otorgado a usuario existente.");
            }
        }
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "fallo el seed del admin inicial -- la app continua sin crearlo");
    }

    try
    {
        var reglaDecisionService = scope.ServiceProvider.GetRequiredService<IReglaDecisionService>();
        await reglaDecisionService.SembrarReglasIniciales();
        await reglaDecisionService.AplicarContenidoPreliminar();
        app.Logger.LogInformation("Reglas de decision iniciales verificadas");
    }
    catch (Exception ex)
    {
        app.Logger.LogError(ex, "fallo el seed de reglas de decision -- la app continua sin actualizarlas");
    }
}

app.Run();

static string GenerarPasswordSegura()
{
    const string alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789!@#$%";
    var bytes = System.Security.Cryptography.RandomNumberGenerator.GetBytes(20);
    var chars = new char[20];
    for (var i = 0; i < bytes.Length; i++)
        chars[i] = alfabeto[bytes[i] % alfabeto.Length];
    return new string(chars);
}
