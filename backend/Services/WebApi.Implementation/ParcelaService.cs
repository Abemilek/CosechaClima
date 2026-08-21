using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class ParcelaService : IParcelaService
{
    private readonly ConnectionBD _connectionBD;
    public ParcelaService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> Registrar(Parcela parcela)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "INSERT INTO Parcelas (UsuarioId, CultivoId, EtapaFenologicaId, TipoSueloId, " +
            "FechaSiembra, AreaMzs, Latitud, Longitud, Municipio, Comunidad, Activa) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@UsuarioId, @CultivoId, @EtapaFenologicaId, @TipoSueloId, " +
            "@FechaSiembra, @AreaMzs, @Latitud, @Longitud, @Municipio, @Comunidad, @Activa)",
        connection);

        command.Parameters.AddWithValue("@UsuarioId", parcela.UsuarioId);
        command.Parameters.AddWithValue("@CultivoId", parcela.CultivoId);
        command.Parameters.AddWithValue("@EtapaFenologicaId", (object?) parcela.EtapaFenologicaId ?? DBNull.Value);
        command.Parameters.AddWithValue("@TipoSueloId", parcela.TipoSueloId);
        command.Parameters.AddWithValue("@FechaSiembra", parcela.FechaSiembra.Date);
        command.Parameters.AddWithValue("@AreaMzs", parcela.AreaMzs);
        command.Parameters.AddWithValue("@Latitud", (object?) parcela.Latitud ?? DBNull.Value);
        command.Parameters.AddWithValue("@Longitud", (object?) parcela.Longitud ?? DBNull.Value);
        command.Parameters.AddWithValue("@Municipio", (object?) parcela.Municipio ?? DBNull.Value);
        command.Parameters.AddWithValue("@Comunidad", (object?) parcela.Comunidad ?? DBNull.Value);
        command.Parameters.AddWithValue("@Activa", parcela.Activa);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<Parcela?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, UsuarioId, CultivoId, EtapaFenologicaId, TipoSueloId, FechaSiembra, " +
            "AreaMzs, Latitud, Longitud, Municipio, Comunidad, FechaRegistro, Activa " +
            "FROM Parcelas WHERE Id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapParcela(reader);
        }

        return null;
    }

    public async Task<bool> Actualizar(Parcela parcela)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "UPDATE Parcelas SET " +
            "Latitud = COALESCE(@Latitud, Latitud), " +
            "Longitud = COALESCE(@Longitud, Longitud), " +
            "AreaMzs = COALESCE(@AreaMzs, AreaMzs), " +
            "Municipio = COALESCE(@Municipio, Municipio), " +
            "Comunidad = COALESCE(@Comunidad, Comunidad) " +
            "WHERE Id = @Id", connection);

        command.Parameters.AddWithValue("@Latitud", (object?) parcela.Latitud ?? DBNull.Value);
        command.Parameters.AddWithValue("@Longitud", (object?) parcela.Longitud ?? DBNull.Value);
        command.Parameters.AddWithValue("@AreaMzs", (object?) parcela.AreaMzs ?? DBNull.Value);
        command.Parameters.AddWithValue("@Municipio", (object?) parcela.Municipio ?? DBNull.Value);
        command.Parameters.AddWithValue("@Comunidad", (object?) parcela.Comunidad ?? DBNull.Value);
        command.Parameters.AddWithValue("@Id", parcela.Id);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }

    public async Task<List<Parcela>> ObtenerPorUsuario (int usuarioId)
    {
        var lista = new List<Parcela>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, UsuarioId, CultivoId, EtapaFenologicaId, TipoSueloId, FechaSiembra, " +
            "AreaMzs, Latitud, Longitud, Municipio, Comunidad, FechaRegistro, Activa " +
            "FROM Parcelas WHERE UsuarioId = @UsuarioId AND Activa = 1", connection);
        command.Parameters.AddWithValue("@UsuarioId", usuarioId);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(MapParcela(reader));
        }

        return lista;
    }

    public async Task<bool> ActualizarEtapa(int parcelaId, int etapaId)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "UPDATE Parcelas SET EtapaFenologicaId = @EtapaId WHERE Id = @ParcelaId",
            connection);
        command.Parameters.AddWithValue("@EtapaId", etapaId);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }

    public async Task<bool> Eliminar (int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "UPDATE Parcelas SET Activa = 0 WHERE Id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }

    private static Parcela MapParcela (SqlDataReader reader)
    {
        return new Parcela
        {
            Id = reader.GetInt32(0),
            UsuarioId = reader.GetInt32(1),
            CultivoId = reader.GetInt32(2),
            EtapaFenologicaId = reader.IsDBNull(3) ? null : reader.GetInt32(3),
            TipoSueloId = reader.GetInt32(4),
            FechaSiembra = reader.GetDateTime(5),
            AreaMzs = reader.GetDecimal(6),
            Latitud = reader.IsDBNull(7) ? null : reader.GetDecimal(7),
            Longitud = reader.IsDBNull(8) ? null : reader.GetDecimal(8),
            Municipio = reader.IsDBNull(9) ? null : reader.GetString(9),
            Comunidad = reader.IsDBNull(10) ? null : reader.GetString(10),
            FechaRegistro = reader.GetDateTime(11),
            Activa = reader.GetBoolean(12)
        };
    }
}