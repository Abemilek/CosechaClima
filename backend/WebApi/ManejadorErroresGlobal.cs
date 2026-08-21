using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
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

            SqlException { Number: 547 }
                => (StatusCodes.Status400BadRequest,
                    "Uno de los valores referenciados (cultivo, suelo, etapa fenologica o evento climatico) no existe en el catalogo"),

            SqlException { Number: 2601 or 2627 }
                => (StatusCodes.Status409Conflict,
                    "ya existe un registro con esos mismos datos"),

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