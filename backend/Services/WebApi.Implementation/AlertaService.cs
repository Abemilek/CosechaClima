using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class AlertaService : IAlertaService
{
    private const string ColumnasAlerta =
        "id, usuario_id, parcela_id, fecha, evento_climatico_id, nivel_riesgo, " +
        "accion1, accion2, accion3, descripcion_alerta, fecha_generacion";

    private readonly ConnectionBD _connectionBD;

    public AlertaService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<Alerta?> ObtenerPorParcelaYFecha(int parcelaId, DateTime fecha)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasAlerta} FROM alertas WHERE parcela_id = @ParcelaId AND fecha = @Fecha",
            connection);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);
        command.Parameters.AddWithValue("@Fecha", FechasUtc.ADateOnly(fecha));

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapAlerta(lector) : null;
    }

    public async Task<List<Alerta>> ObtenerRecientes(int limite)
    {
        var lista = new List<Alerta>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasAlerta} FROM alertas ORDER BY fecha_generacion DESC, id DESC LIMIT @Limite",
            connection);
        command.Parameters.AddWithValue("@Limite", limite);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
            lista.Add(MapAlerta(lector));

        return lista;
    }

    // Upsert atomico sobre UNIQUE (parcela_id, fecha).
    public async Task<int> GuardarOActualizar(Alerta alerta)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO alertas (usuario_id, parcela_id, fecha, evento_climatico_id, nivel_riesgo, " +
            "accion1, accion2, accion3, descripcion_alerta) " +
            "VALUES (@UsuarioId, @ParcelaId, @Fecha, @EventoClimaticoId, @NivelRiesgo, " +
            "@Accion1, @Accion2, @Accion3, @DescripcionAlerta) " +
            "ON CONFLICT (parcela_id, fecha) DO UPDATE SET " +
            "evento_climatico_id = EXCLUDED.evento_climatico_id, " +
            "nivel_riesgo = EXCLUDED.nivel_riesgo, " +
            "accion1 = EXCLUDED.accion1, accion2 = EXCLUDED.accion2, accion3 = EXCLUDED.accion3, " +
            "descripcion_alerta = EXCLUDED.descripcion_alerta, " +
            "fecha_generacion = now() " +
            "RETURNING id", connection);

        command.Parameters.AddWithValue("@UsuarioId", alerta.UsuarioId);
        command.Parameters.AddWithValue("@ParcelaId", alerta.ParcelaId);
        command.Parameters.AddWithValue("@Fecha", FechasUtc.ADateOnly(alerta.Fecha));
        command.Parameters.AddWithValue("@EventoClimaticoId", alerta.EventoClimaticoId);
        command.Parameters.AddWithValue("@NivelRiesgo", alerta.NivelRiesgo);
        command.Parameters.AddWithValue("@Accion1", alerta.Accion1);
        command.Parameters.AddWithValue("@Accion2", alerta.Accion2);
        command.Parameters.AddWithValue("@Accion3", alerta.Accion3);
        command.Parameters.AddWithValue("@DescripcionAlerta", alerta.DescripcionAlerta);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    private static Alerta MapAlerta(NpgsqlDataReader lector) => new()
    {
        Id = lector.GetInt32(0),
        UsuarioId = lector.GetInt32(1),
        ParcelaId = lector.GetInt32(2),
        Fecha = FechasUtc.DeDateOnly(lector.GetFieldValue<DateOnly>(3)),
        EventoClimaticoId = lector.GetInt32(4),
        NivelRiesgo = lector.GetString(5),
        Accion1 = lector.GetString(6),
        Accion2 = lector.GetString(7),
        Accion3 = lector.GetString(8),
        DescripcionAlerta = lector.GetString(9),
        FechaGeneracion = lector.GetDateTime(10)
    };
}
