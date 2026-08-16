using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Implementation;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using WebApi.Implementation.Security;
using WebApi;
using Microsoft.AspNetCore.RateLimiting;

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

var jwtConfig = builder.Configuration.GetSection("Jwt");
var secretKey = jwtConfig["SecretKey"]!;

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


// registro del http client
builder.Services.AddHttpClient<IProveedorClimaticoService, OpenMeteoService>(cliente =>
{
    cliente.BaseAddress = new Uri("https://api.open-meteo.com/v1/forecast");
    cliente.Timeout = TimeSpan.FromSeconds(10);
});

// conexion a la base de datos
builder.Services.AddScoped<ConnectionBD>();

// cada servicio registrado, por cada interfaz que exista
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
builder.Services.AddScoped<TokenGenerator>();
builder.Services.AddExceptionHandler<ManejadorErroresGlobal>();
builder.Services.AddProblemDetails();

builder.Services.AddHealthChecks()
    .AddCheck<ChequeoBaseDeDatos>("base-de-datos");

builder.Services.AddRateLimiter(opciones =>
{
    opciones.AddSlidingWindowLimiter("auth", limiteOpciones =>
    {
        limiteOpciones.PermitLimit = 5;
        limiteOpciones.Window = TimeSpan.FromMinutes(1);
        limiteOpciones.SegmentsPerWindow = 2;
        limiteOpciones.QueueLimit = 0;
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

app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.UseRateLimiter();

app.MapControllers();

app.Run();
