using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class EtapaFenologicaService : IEtapaFenologicaService
{
    private readonly ConnectionBD _connectionBD;

    public EtapaFenologicaService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<List<EtapaFenologica>> ObtenerTodas()
    {
        var lista = new List<EtapaFenologica>();

        using var connection = _connectionBD.CrearConexion();
        // NULLS FIRST conserva el comportamiento de SQL Server (los NULL se ordenaban primero en ASC).
        using var command = new NpgsqlCommand(
            "SELECT id, nombre, descripcion, dias_desde_siembra FROM etapas_fenologicas " +
            "ORDER BY dias_desde_siembra ASC NULLS FIRST, id", connection);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(new EtapaFenologica
            {
                Id = reader.GetInt32(0),
                Nombre = reader.GetString(1),
                Descripcion = reader.IsDBNull(2) ? null : reader.GetString(2),
                DiasDesdeSiembra = reader.IsDBNull(3) ? null : reader.GetInt32(3)
            });
        }

        return lista;
    }

    public async Task<EtapaFenologica> CalcularDesdeFecha(DateTime fechaSiembra)
    {
        var etapas = await ObtenerTodas();

        if (etapas.Count == 0)
            throw new InvalidOperationException("no hay etapas fenologicas configuradas en el catalogo");

        var diasTranscurridos = (FechasUtc.HoyNicaragua() - fechaSiembra.Date).Days;

        var etapaCalculada = etapas
            .Where(e => e.DiasDesdeSiembra is not null && e.DiasDesdeSiembra <= diasTranscurridos)
            .OrderByDescending(e => e.DiasDesdeSiembra)
            .FirstOrDefault();

        return etapaCalculada ?? etapas.OrderBy(e => e.DiasDesdeSiembra ?? 0).First();
    }
}
