using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Implementation;
using WebApi.Controllers;
using WebApi.Models;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
builder.Services.AddScoped<ConnectionBD>();
builder.Services.AddScoped<IAlertaService, AlertaService>();
builder.Services.AddScoped<IMotorDecisionesService, MotorDecisionesService>();

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
