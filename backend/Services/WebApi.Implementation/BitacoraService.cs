using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class BitacoraService : IBitacoraService
{
    private const string ColumnasEntrada =
        "id, usuario_id, parcela_id, fecha, evento_climatico_id, nivel_riesgo, " +
        "accion1_texto, accion2_texto, accion3_texto, accion1_completada, accion2_completada, " +
        "accion3_completada, notas, fecha_sincronizacion";

    private readonly ConnectionBD _connectionBD;

    public BitacoraService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> RegistrarEntrada(BitacoraCampo entrada)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO bitacora_campo (usuario_id, parcela_id, fecha, evento_climatico_id, nivel_riesgo, " +
            "accion1_texto, accion2_texto, accion3_texto, notas) " +
            "VALUES (@UsuarioId, @ParcelaId, @Fecha, @EventoClimaticoId, @NivelRiesgo, " +
            "@Accion1Texto, @Accion2Texto, @Accion3Texto, @Notas) " +
            "RETURNING id", connection);

        command.Parameters.AddWithValue("@UsuarioId", entrada.UsuarioId);
        command.Parameters.AddWithValue("@ParcelaId", entrada.ParcelaId);
        // timestamptz: Npgsql exige DateTime con Kind=Utc
        command.Parameters.AddWithValue("@Fecha", FechasUtc.AUtc(entrada.Fecha));
        command.Parameters.AddWithValue("@EventoClimaticoId", entrada.EventoClimaticoId);
        command.Parameters.AddWithValue("@NivelRiesgo", entrada.NivelRiesgo);
        command.Parameters.AddWithValue("@Accion1Texto", entrada.Accion1Texto);
        command.Parameters.AddWithValue("@Accion2Texto", entrada.Accion2Texto);
        command.Parameters.AddWithValue("@Accion3Texto", entrada.Accion3Texto);
        command.Parameters.AddWithValue("@Notas", (object?)entrada.Notas ?? DBNull.Value);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<BitacoraCampo?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasEntrada} FROM bitacora_campo WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapEntrada(lector) : null;
    }

    public async Task<List<BitacoraCampo>> ObtenerHistorial(int usuarioId)
    {
        var lista = new List<BitacoraCampo>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasEntrada} FROM bitacora_campo " +
            "WHERE usuario_id = @UsuarioId ORDER BY fecha DESC, id DESC", connection);
        command.Parameters.AddWithValue("@UsuarioId", usuarioId);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
            lista.Add(MapEntrada(lector));

        return lista;
    }

    public async Task<bool> MarcarAccionCompletada(int entradaId, int numeroAccion)
    {
        // El nombre de columna sale de este switch cerrado, nunca de la entrada del usuario.
        var columna = numeroAccion switch
        {
            1 => "accion1_completada",
            2 => "accion2_completada",
            3 => "accion3_completada",
            _ => throw new ArgumentOutOfRangeException(nameof(numeroAccion), "debe ser 1, 2 o 3")
        };

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"UPDATE bitacora_campo SET {columna} = true WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@Id", entradaId);

        await connection.OpenAsync();
        var filasAfectadas = await command.ExecuteNonQueryAsync();
        return filasAfectadas > 0;
    }

    public async Task<string> CompartirResumen(int usuarioId)
    {
        var historial = await ObtenerHistorial(usuarioId);
        var ultimos = historial.Take(5);

        var lineas = ultimos.Select(entrada =>
            $"{entrada.Fecha.Add(FechasUtc.OffsetNicaragua):dd/MM}: riesgo {entrada.NivelRiesgo} - " +
            $"{(entrada.Accion1Completada ? "[x]" : "[ ]")} {entrada.Accion1Texto}");

        return string.Join("\n", lineas);
    }

    private static BitacoraCampo MapEntrada(NpgsqlDataReader lector) => new()
    {
        Id = lector.GetInt32(0),
        UsuarioId = lector.GetInt32(1),
        ParcelaId = lector.GetInt32(2),
        Fecha = lector.GetDateTime(3),
        EventoClimaticoId = lector.GetInt32(4),
        NivelRiesgo = lector.GetString(5),
        Accion1Texto = lector.GetString(6),
        Accion2Texto = lector.GetString(7),
        Accion3Texto = lector.GetString(8),
        Accion1Completada = lector.GetBoolean(9),
        Accion2Completada = lector.GetBoolean(10),
        Accion3Completada = lector.GetBoolean(11),
        Notas = lector.IsDBNull(12) ? null : lector.GetString(12),
        FechaSincronizacion = lector.GetDateTime(13)
    };
}
