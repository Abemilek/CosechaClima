using System.Data;
using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class AlertaService : IAlertaService
{
    public readonly ConnectionBD _connectionBD;

    public AlertaService (ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<Alerta?> ObtenerPorParcelaYFecha (int parcelaId, DateTime fecha)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, UsuarioId, ParcelaId, Fecha, EventoClimaticoId, NivelRiesgo, " +
            "Accion1, Accion2, Accion3, DescripcionAlerta, FechaGeneracion " +
            "FROM Alertas WHERE ParcelaId = @ParcelaId AND Fecha = @Fecha", connection);
            command.Parameters.AddWithValue("@ParcelaId", parcelaId);
            command.Parameters.AddWithValue("@Fecha", fecha.Date);

            await connection.OpenAsync();
            using var lector = await command.ExecuteReaderAsync();

            if (await lector.ReadAsync())
            {
                return new Alerta
                {
                    Id = lector.GetInt32(0),
                    UsuarioId = lector.GetInt32(1),
                    ParcelaId = lector.GetInt32(2),
                    Fecha = lector.GetDateTime(3),
                    EventoClimaticoId = lector.GetInt32(4),
                    NivelRiesgo = lector.GetString(5),
                    Accion1 = lector.GetString(6),
                    Accion2 = lector.GetString(7),
                    Accion3 = lector.GetString(8),
                    DescripcionAlerta = lector.GetString(9),
                    FechaGeneracion = lector.GetDateTime(10)
                };
            }
            return null;
    }

    public async Task<int> GuardarOActualizar (Alerta alerta)
    {
        var existing = await ObtenerPorParcelaYFecha(alerta.ParcelaId, alerta.Fecha);

        using var connection = _connectionBD.CrearConexion();
        await connection.OpenAsync();

        if (existing is null)
        {
            using var commandInsert = new SqlCommand(
                "INSERT INTO Alertas (UsuarioId, ParcelaId, Fecha, EventoClimaticoId, NivelRiesgo, " +
                "Accion1, Accion2, Accion3, DescripcionAlerta) " +
                "OUTPUT INSERTED.Id " +
                "Values(@UsuarioId, @ParcelaId, @Fecha, @EventoClimaticoId, @NivelRiesgo, "+
                "@Accion1, @Accion2, @Accion3, @DescripcionAlerta)", connection);

                AddParameters(commandInsert, alerta);
                var result = await commandInsert.ExecuteScalarAsync();
                var newId = Convert.ToInt32(result);
                // var newId = (int)await commandInsert.ExecuteScalarAsync();
                return newId;
        }
        else
        {
            using var commandUpdate = new SqlCommand(
                "UPDATE Alertas SET EventoClimaticoId = @EventoClimaticoId, NivelRiesgo = @NivelRiesgo, " +
                "Accion1 = @Accion1, Accion2 = @Accion2, Accion3 = @Accion3, " +
                "DescripcionAlerta = @DescripcionAlerta, FechaGeneracion = GETDATE() " +
                "WHERE Id = @Id", connection);

            AddParameters(commandUpdate, alerta);
            commandUpdate.Parameters.AddWithValue("@Id", existing.Id);
            await commandUpdate.ExecuteNonQueryAsync();
            return existing.Id;
        }
    }

    private static void AddParameters(SqlCommand command, Alerta alerta)
    {
        command.Parameters.AddWithValue("@UsuarioId", alerta.UsuarioId);
        command.Parameters.AddWithValue("@ParcelaId", alerta.ParcelaId);
        command.Parameters.AddWithValue("@Fecha", alerta.Fecha.Date);
        command.Parameters.AddWithValue("@EventoClimaticoId", alerta.EventoClimaticoId);
        command.Parameters.AddWithValue("@NivelRiesgo", alerta.NivelRiesgo);
        command.Parameters.AddWithValue("@Accion1", alerta.Accion1);
        command.Parameters.AddWithValue("@Accion2", alerta.Accion2);
        command.Parameters.AddWithValue("@Accion3", alerta.Accion3);
        command.Parameters.AddWithValue("@DescripcionAlerta", alerta.DescripcionAlerta);
    }

} 