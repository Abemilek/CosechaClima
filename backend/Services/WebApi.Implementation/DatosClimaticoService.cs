using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class DatosClimaticoService : IDatosClimaticoService
{
    private readonly ConnectionBD _connectionBD;

    public DatosClimaticoService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> GuardarDatos(DatosClimaticos datos)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "INSERT INTO DatosClimaticos (ParcelaId, Fecha, TemperaturaMedia, TemperaturaMax, " +
            "TemperaturaMin, Precipitacion, HumedadRelativa, VientoVelocidad, RadiacionSolar, " +
            "FuenteNASA) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@ParcelaId, @Fecha, @TMedia, @TMax, @TMin, @Precipitacion, @Humedad, " +
            "@Viento, @Radiacion, @Fuente)", connection);

        AgregarParametros(command, datos);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<int> GuardarOActualizar(DatosClimaticos datos)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "MERGE DatosClimaticos AS destino " +
            "USING (SELECT @ParcelaId AS ParcelaId, @Fecha AS Fecha) AS origen " +
            "ON destino.ParcelaId = origen.ParcelaId AND destino.Fecha = origen.Fecha " +
            "WHEN MATCHED THEN UPDATE SET " +
            "   TemperaturaMedia = @TMedia, TemperaturaMax = @TMax, TemperaturaMin = @TMin, " +
            "   Precipitacion = @Precipitacion, HumedadRelativa = @Humedad, " +
            "   VientoVelocidad = @Viento, RadiacionSolar = @Radiacion, " +
            "   FuenteNASA = @Fuente, FechaDescarga = GETDATE() " +
            "WHEN NOT MATCHED THEN INSERT " +
            "   (ParcelaId, Fecha, TemperaturaMedia, TemperaturaMax, TemperaturaMin, " +
            "   Precipitacion, HumedadRelativa, VientoVelocidad, RadiacionSolar, FuenteNASA) " +
            "   VALUES (@ParcelaId, @Fecha, @TMedia, @TMax, @TMin, @Precipitacion, @Humedad, " +
            "   @Viento, @Radiacion, @Fuente) " +
            "OUTPUT INSERTED.Id;", connection);

        AgregarParametros(command, datos);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<DatosClimaticos> ObtenerPorParcelaYFecha(int parcelaId, DateTime fecha)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, ParcelaId, Fecha, TemperaturaMedia, TemperaturaMax, TemperaturaMin, " +
            "Precipitacion, HumedadRelativa, VientoVelocidad, RadiacionSolar, FuenteNASA, " +
            "FechaDescarga FROM DatosClimaticos WHERE ParcelaId = @ParcelaId AND Fecha = @Fecha",
            connection);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);
        command.Parameters.AddWithValue("@Fecha", fecha.Date);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        if (await reader.ReadAsync())
        {
            return MapDato(reader);
        }

        throw new InvalidOperationException(
            $"No hay datos climaticos para la parcela {parcelaId} en la fecha {fecha:yyyy-MM-dd}");
    }

    public async Task<List<DatosClimaticos>> ObtenerUltimosDatos(int parcelaId, int dias = 7)
    {
        var lista = new List<DatosClimaticos>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            // los dias mas recientes que existan
            "SELECT TOP (@Dias) Id, ParcelaId, Fecha, TemperaturaMedia, TemperaturaMax, " +
            "TemperaturaMin, Precipitacion, HumedadRelativa, VientoVelocidad, RadiacionSolar, " +
            "FuenteNASA, FechaDescarga FROM DatosClimaticos " +
            "WHERE ParcelaId = @ParcelaId ORDER BY Fecha DESC", connection);
        command.Parameters.AddWithValue("@Dias", dias);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            lista.Add(MapDato(reader));
        }

        return lista;
    }

    public Task<List<DatosClimaticos>> ObtenerPrediccion(int parcelaId)
    {
        throw new NotImplementedException(
            "ObtenerPrediccion pendiente: falta definir la fuente de pronostico.");
    }

    private static void AgregarParametros(SqlCommand command, DatosClimaticos datos)
    {
        command.Parameters.AddWithValue("@ParcelaId", datos.ParcelaId);
        command.Parameters.AddWithValue("@Fecha", datos.Fecha.Date);
        command.Parameters.AddWithValue("@TMedia", (object?)datos.TemperaturaMedia ?? DBNull.Value);
        command.Parameters.AddWithValue("@TMax", (object?)datos.TemperaturaMax ?? DBNull.Value);
        command.Parameters.AddWithValue("@TMin", (object?)datos.TemperaturaMin ?? DBNull.Value);
        command.Parameters.AddWithValue("@Precipitacion", (object?)datos.Precipitacion ?? DBNull.Value);
        command.Parameters.AddWithValue("@Humedad", (object?)datos.HumedadRelativa ?? DBNull.Value);
        command.Parameters.AddWithValue("@Viento", (object?)datos.VientoVelocidad ?? DBNull.Value);
        command.Parameters.AddWithValue("@Radiacion", (object?)datos.RadiacionSolar ?? DBNull.Value);
        command.Parameters.AddWithValue("@Fuente", datos.FuenteNASA);
    }

    private static DatosClimaticos MapDato(SqlDataReader reader)
    {
        return new DatosClimaticos
        {
            Id = reader.GetInt32(0),
            ParcelaId = reader.GetInt32(1),
            Fecha = reader.GetDateTime(2),
            TemperaturaMedia = reader.IsDBNull(3) ? null : reader.GetDecimal(3),
            TemperaturaMax = reader.IsDBNull(4) ? null : reader.GetDecimal(4),
            TemperaturaMin = reader.IsDBNull(5) ? null : reader.GetDecimal(5),
            Precipitacion = reader.IsDBNull(6) ? null : reader.GetDecimal(6),
            HumedadRelativa = reader.IsDBNull(7) ? null : reader.GetDecimal(7),
            VientoVelocidad = reader.IsDBNull(8) ? null : reader.GetDecimal(8),
            RadiacionSolar = reader.IsDBNull(9) ? null : reader.GetDecimal(9),
            FuenteNASA = reader.GetString(10),
            FechaDescarga = reader.GetDateTime(11)
        };
    }
}