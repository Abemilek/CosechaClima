using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Implementation;
using System.Text;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using WebApi.Implementation.Security;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();


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
builder.Services.AddHttpClient<INasaPowerService, NasaPowerService>(cliente =>
{
    cliente.BaseAddress = new Uri("https://power.larc.nasa.gov/api/temporal/daily/point");
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
builder.Services.AddAuthorization();
builder.Services.AddScoped<TokenGenerator>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthentication();

app.UseAuthorization();

app.MapControllers();

app.Run();
