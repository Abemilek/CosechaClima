using Microsoft.Extensions.Diagnostics.HealthChecks;
using WebApi.Implementation.Connection;

namespace WebApi;

public class ChequeoBaseDeDatos : IHealthCheck
{
    private readonly ConnectionBD _connectionBD;

    public ChequeoBaseDeDatos(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(
        HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        try
        {
            using var connection = _connectionBD.CrearConexion();
            await connection.OpenAsync(cancellationToken);
            return HealthCheckResult.Healthy("conexion a la base de datos exitosa");
        }
        catch (Exception ex)
        {
            return HealthCheckResult.Unhealthy("no se pudo conectar a la base de datos", ex);
        }
    }
}