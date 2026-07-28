using Microsoft.Data.SqlClient;
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
        using var command = new SqlCommand(
            "SELECT Id, UsuarioId, LluviaIntensaMm, VientoFuerteKmh, CaniculaDias, " +
            "VariedadCultivo, TieneRiego, HorarioSms " +
            "FROM UmbralConfiguracion WHERE UsuarioId = @UsuarioId", connection);
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
                HorarioSms = TimeOnly.FromTimeSpan(reader.GetTimeSpan(7))
            };
        }

        return null;
    }

    public async Task<int> CrearOActualizar(UmbralConfiguracion umbral)
    {
        var existente = await ObtenerPorUsuario(umbral.UsuarioId);

        using var connection = _connectionBD.CrearConexion();
        await connection.OpenAsync();

        if (existente is null)
        {
            using var commandInsert = new SqlCommand(
                "INSERT INTO UmbralConfiguracion (UsuarioId, LluviaIntensaMm, VientoFuerteKmh, " +
                "CaniculaDias, VariedadCultivo, TieneRiego, HorarioSms) " +
                "OUTPUT INSERTED.Id " +
                "VALUES (@UsuarioId, @Lluvia, @Viento, @Canicula, @Variedad, @Riego, @Horario)",
                connection);

            AgregarParametros(commandInsert, umbral);
            var result = await commandInsert.ExecuteScalarAsync();
            return Convert.ToInt32(result);
        }
        else
        {
            using var commandUpdate = new SqlCommand(
                "UPDATE UmbralConfiguracion SET LluviaIntensaMm = @Lluvia, " +
                "VientoFuerteKmh = @Viento, CaniculaDias = @Canicula, " +
                "VariedadCultivo = @Variedad, TieneRiego = @Riego, HorarioSms = @Horario " +
                "WHERE Id = @Id", connection);

            AgregarParametros(commandUpdate, umbral);
            commandUpdate.Parameters.AddWithValue("@Id", existente.Id);
            await commandUpdate.ExecuteNonQueryAsync();
            return existente.Id;
        }
    }

    public async Task<bool> ActualizarUmbrales(int id, int? lluvia, int? viento, int? canicula)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "UPDATE UmbralConfiguracion SET " +
            "LluviaIntensaMm = COALESCE(@Lluvia, LluviaIntensaMm), " +
            "VientoFuerteKmh = COALESCE(@Viento, VientoFuerteKmh), " +
            "CaniculaDias = COALESCE(@Canicula, CaniculaDias) " +
            "WHERE Id = @Id", connection);

        command.Parameters.AddWithValue("@Lluvia", (object?)lluvia ?? DBNull.Value);
        command.Parameters.AddWithValue("@Viento", (object?)viento ?? DBNull.Value);
        command.Parameters.AddWithValue("@Canicula", (object?)canicula ?? DBNull.Value);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }

    private static void AgregarParametros(SqlCommand command, UmbralConfiguracion umbral)
    {
        command.Parameters.AddWithValue("@UsuarioId", umbral.UsuarioId);
        command.Parameters.AddWithValue("@Lluvia", umbral.LluviaIntensaMm);
        command.Parameters.AddWithValue("@Viento", umbral.VientoFuerteKmh);
        command.Parameters.AddWithValue("@Canicula", umbral.CaniculaDias);
        command.Parameters.AddWithValue("@Variedad", umbral.VariedadCultivo);
        command.Parameters.AddWithValue("@Riego", umbral.TieneRiego);
        command.Parameters.AddWithValue("@Horario", umbral.HorarioSms.ToTimeSpan());
    }
}