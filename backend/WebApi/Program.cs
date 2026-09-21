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

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
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
        var origenesPermitidos = builder.Configuration
            .GetSection("Cors:AllowedOrigins")
            .Get<string[]>() ?? [];

        politica.WithOrigins(origenesPermitidos)
            .AllowAnyHeader()
            .AllowAnyMethod();
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
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(secretKey))
        };
    });


builder.Services.AddHttpClient<IProveedorClimaticoService, OpenMeteoService>(cliente =>
{
    cliente.BaseAddress = new Uri("https://api.open-meteo.com/v1/forecast");
    cliente.Timeout = TimeSpan.FromSeconds(10);
});

builder.Services.AddSingleton<ConnectionBD>();

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

app.UseExceptionHandler();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.MapHealthChecks("/health");

if (!app.Environment.IsDevelopment())
{
    app.UseHttpsRedirection();
}

app.UseCors("FrontendPolicy");

app.UseAuthentication();

app.UseAuthorization();

app.UseRateLimiter();

app.MapControllers();

using (var scope = app.Services.CreateScope())
{
    try
    {
        var config = scope.ServiceProvider.GetRequiredService<IConfiguration>();
        var emailAdmin = config["AdminSeed:Email"];
        var passwordAdmin = config["AdminSeed:Password"];

        var seedConfigurado = !string.IsNullOrWhiteSpace(emailAdmin)
            || !string.IsNullOrWhiteSpace(passwordAdmin);

        if (seedConfigurado)
        {
            var emailValido = !string.IsNullOrWhiteSpace(emailAdmin)
                && Regex.IsMatch(emailAdmin, @"^[^@\s]+@[^@\s]+\.[^@\s]+$");
            var passwordValida = !string.IsNullOrWhiteSpace(passwordAdmin)
                && passwordAdmin.Length >= 8;

            if (!emailValido || !passwordValida)
            {
                app.Logger.LogWarning(
                    "AdminSeed configurado con formato invalido (email debe ser valido, " +
                    "password debe tener al menos 8 caracteres) -- se omite el seed del admin");
            }
            else
            {
                var usuarioService = scope.ServiceProvider.GetRequiredService<IUsuarioService>();
                var existente = await usuarioService.ObtenerPorEmail(emailAdmin!);

                if (existente is null)
                {
                    var nombreAdmin = config["AdminSeed:Nombre"] ?? "Admin";
                    var id = await usuarioService.RegistrarConEmail(
                        new Usuario { Nombre = nombreAdmin, Email = emailAdmin! }, passwordAdmin!);
                    await usuarioService.MarcarComoAdmin(id);
                    app.Logger.LogInformation("Admin inicial creado: {Email}", emailAdmin);
                }
                else if (!existente.EsAdmin)
                {
                    await usuarioService.MarcarComoAdmin(existente.Id);
                    app.Logger.LogInformation(
                        "Rol Admin otorgado a usuario existente: {Email}", emailAdmin);
                }
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
