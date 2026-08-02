using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class BitacoraService : IBitacoraService
{
    private readonly ConnectionBD _connectionBD;

    public BitacoraService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> RegistrarEntrada(BitacoraCampo entrada)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "INSERT INTO BitacoraCampo (UsuarioId, ParcelaId, Fecha, EventoClimaticoId, NivelRiesgo, " +
            "Accion1Texto, Accion2Texto, Accion3Texto, Notas) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@UsuarioId, @ParcelaId, @Fecha, @EventoClimaticoId, @NivelRiesgo, " +
            "@Accion1Texto, @Accion2Texto, @Accion3Texto, @Notas)", connection);

        command.Parameters.AddWithValue("@UsuarioId", entrada.UsuarioId);
        command.Parameters.AddWithValue("@ParcelaId", entrada.ParcelaId);
        command.Parameters.AddWithValue("@Fecha", entrada.Fecha.Date);
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

    public async Task<List<BitacoraCampo>> ObtenerHistorial(int usuarioId)
    {
        var lista = new List<BitacoraCampo>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, UsuarioId, ParcelaId, Fecha, EventoClimaticoId, NivelRiesgo, " +
            "Accion1Texto, Accion2Texto, Accion3Texto, Accion1Completada, Accion2Completada, " +
            "Accion3Completada, Notas, FechaSincronizacion FROM BitacoraCampo " +
            "WHERE UsuarioId = @UsuarioId ORDER BY Fecha DESC", connection);
        command.Parameters.AddWithValue("@UsuarioId", usuarioId);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
        {
            lista.Add(new BitacoraCampo
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
            });
        }

        return lista;
    }

    public async Task<bool> MarcarAccionCompletada(int entradaId, int numeroAccion)
    {
        var columna = numeroAccion switch
        {
            1 => "Accion1Completada",
            2 => "Accion2Completada",
            3 => "Accion3Completada",
            _ => throw new ArgumentOutOfRangeException(nameof(numeroAccion), "debe ser 1, 2 0 3")
        };

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            $"UPDATE BitacoraCampo SET {columna} = 1 WHERE Id = @Id", connection);
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
            $"{entrada.Fecha:dd/MM}: riesgo {entrada.NivelRiesgo} - " +
            $"{(entrada.Accion1Completada ? "[x]" : "[ ]")} {entrada.Accion1Texto}");

        return string.Join("\n", lineas);
    }
}