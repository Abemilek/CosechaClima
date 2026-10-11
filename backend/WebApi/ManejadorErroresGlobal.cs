using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Npgsql;
using WebApi.Implementation.Exceptions;

namespace WebApi;

public class ManejadorErroresGlobal : IExceptionHandler
{
    private readonly ILogger<ManejadorErroresGlobal> _logger;

    public ManejadorErroresGlobal(ILogger<ManejadorErroresGlobal> logger)
    {
        _logger = logger;
    }

    public async ValueTask<bool> TryHandleAsync(
        HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        _logger.LogError(exception, "excepcion no controlada en {Path}", httpContext.Request.Path);

        var (statusCode, titulo) = exception switch
        {
            RecursoNoEncontradoException
                => (StatusCodes.Status404NotFound, exception.Message),

            FlujoIncompletoException
                => (StatusCodes.Status404NotFound, exception.Message),

            UnauthorizedAccessException
                => (StatusCodes.Status401Unauthorized, "no autorizado"),

            // Codigos SQLSTATE de PostgreSQL (apendice A de la documentacion oficial):
            // 23503 foreign_key_violation, 23505 unique_violation, 23514 check_violation.
            PostgresException { SqlState: "23503" }
                => (StatusCodes.Status400BadRequest,
                    "Uno de los valores referenciados (cultivo, suelo, etapa fenologica o evento climatico) no existe en el catalogo"),

            PostgresException { SqlState: "23505" }
                => (StatusCodes.Status409Conflict,
                    "ya existe un registro con esos mismos datos"),

            PostgresException { SqlState: "23514" }
                => (StatusCodes.Status400BadRequest,
                    "alguno de los valores enviados no cumple las reglas de validacion de la base de datos"),

            // Caida de red o reinicio de la base: el cliente puede reintentar.
            NpgsqlException { IsTransient: true }
                => (StatusCodes.Status503ServiceUnavailable,
                    "la base de datos no esta disponible por el momento, intenta de nuevo"),

            _ => (StatusCodes.Status500InternalServerError, "ocurrio un error inesperado")
        };

        httpContext.Response.StatusCode = statusCode;

        await httpContext.Response.WriteAsJsonAsync(new ProblemDetails
        {
            Status = statusCode,
            Title = titulo,
            Instance = httpContext.Request.Path
        }, cancellationToken);

        return true;
    }
}