using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class UmbralConfiguracionService : IUmbralConfiguracionService
{
    private readonly ConnectionBD _connectionBD;

    public UmbralConfiguracionService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<UmbralConfiguracion?> ObtenerPorUsuario(int usuarioId)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "SELECT id, usuario_id, lluvia_intensa_mm, viento_fuerte_kmh, canicula_dias, " +
            "variedad_cultivo, tiene_riego, horario_sms " +
            "FROM umbrales_configuracion WHERE usuario_id = @UsuarioId", connection);
        command.Parameters.AddWithValue("@UsuarioId", usuarioId);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return new UmbralConfiguracion
            {
                Id = reader.GetInt32(0),
                UsuarioId = reader.GetInt32(1),
                LluviaIntensaMm = reader.GetInt32(2),
                VientoFuerteKmh = reader.GetInt32(3),
                CaniculaDias = reader.GetInt32(4),
                VariedadCultivo = reader.GetString(5),
                TieneRiego = reader.GetBoolean(6),
                HorarioSms = reader.GetFieldValue<TimeOnly>(7)
            };
        }

        return null;
    }

    /// <summary>
    /// Un solo statement atomico (INSERT ... ON CONFLICT DO UPDATE) en lugar de
    /// "leer y luego insertar/actualizar", que podia duplicar bajo concurrencia.
    /// usuario_id es UNIQUE, que es lo que habilita el ON CONFLICT.
    /// </summary>
    public async Task<int> CrearOActualizar(UmbralConfiguracion umbral)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO umbrales_configuracion (usuario_id, lluvia_intensa_mm, viento_fuerte_kmh, " +
            "canicula_dias, variedad_cultivo, tiene_riego, horario_sms) " +
            "VALUES (@UsuarioId, @Lluvia, @Viento, @Canicula, @Variedad, @Riego, @Horario) " +
            "ON CONFLICT (usuario_id) DO UPDATE SET " +
            "lluvia_intensa_mm = EXCLUDED.lluvia_intensa_mm, " +
            "viento_fuerte_kmh = EXCLUDED.viento_fuerte_kmh, " +
            "canicula_dias = EXCLUDED.canicula_dias, " +
            "variedad_cultivo = EXCLUDED.variedad_cultivo, " +
            "tiene_riego = EXCLUDED.tiene_riego, " +
            "horario_sms = EXCLUDED.horario_sms " +
            "RETURNING id", connection);

        command.Parameters.AddWithValue("@UsuarioId", umbral.UsuarioId);
        command.Parameters.AddWithValue("@Lluvia", umbral.LluviaIntensaMm);
        command.Parameters.AddWithValue("@Viento", umbral.VientoFuerteKmh);
        command.Parameters.AddWithValue("@Canicula", umbral.CaniculaDias);
        command.Parameters.AddWithValue("@Variedad", umbral.VariedadCultivo);
        command.Parameters.AddWithValue("@Riego", umbral.TieneRiego);
        command.Parameters.AddWithValue("@Horario", umbral.HorarioSms);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<bool> ActualizarUmbrales(int id, int? lluvia, int? viento, int? canicula)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE umbrales_configuracion SET " +
            "lluvia_intensa_mm = COALESCE(@Lluvia, lluvia_intensa_mm), " +
            "viento_fuerte_kmh = COALESCE(@Viento, viento_fuerte_kmh), " +
            "canicula_dias = COALESCE(@Canicula, canicula_dias) " +
            "WHERE id = @Id", connection);

        command.Parameters.AddWithValue("@Lluvia", (object?)lluvia ?? DBNull.Value);
        command.Parameters.AddWithValue("@Viento", (object?)viento ?? DBNull.Value);
        command.Parameters.AddWithValue("@Canicula", (object?)canicula ?? DBNull.Value);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }
}
