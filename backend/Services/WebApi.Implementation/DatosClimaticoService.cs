using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class DatosClimaticoService : IDatosClimaticoService
{
    private const string ColumnasDato =
        "id, parcela_id, fecha, temperatura_media, temperatura_max, temperatura_min, " +
        "precipitacion, humedad_relativa, viento_velocidad, radiacion_solar, fuente_clima, fecha_descarga";

    private readonly ConnectionBD _connectionBD;

    public DatosClimaticoService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> GuardarDatos(DatosClimaticos datos)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO datos_climaticos (parcela_id, fecha, temperatura_media, temperatura_max, " +
            "temperatura_min, precipitacion, humedad_relativa, viento_velocidad, radiacion_solar, " +
            "fuente_clima) " +
            "VALUES (@ParcelaId, @Fecha, @TMedia, @TMax, @TMin, @Precipitacion, @Humedad, " +
            "@Viento, @Radiacion, @Fuente) " +
            "RETURNING id", connection);

        AgregarParametros(command, datos);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    // MERGE de SQL Server -> INSERT ... ON CONFLICT DO UPDATE (upsert atomico nativo de PostgreSQL).
    public async Task<int> GuardarOActualizar(DatosClimaticos datos)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO datos_climaticos (parcela_id, fecha, temperatura_media, temperatura_max, " +
            "temperatura_min, precipitacion, humedad_relativa, viento_velocidad, radiacion_solar, " +
            "fuente_clima) " +
            "VALUES (@ParcelaId, @Fecha, @TMedia, @TMax, @TMin, @Precipitacion, @Humedad, " +
            "@Viento, @Radiacion, @Fuente) " +
            "ON CONFLICT (parcela_id, fecha) DO UPDATE SET " +
            "temperatura_media = EXCLUDED.temperatura_media, " +
            "temperatura_max = EXCLUDED.temperatura_max, " +
            "temperatura_min = EXCLUDED.temperatura_min, " +
            "precipitacion = EXCLUDED.precipitacion, " +
            "humedad_relativa = EXCLUDED.humedad_relativa, " +
            "viento_velocidad = EXCLUDED.viento_velocidad, " +
            "radiacion_solar = EXCLUDED.radiacion_solar, " +
            "fuente_clima = EXCLUDED.fuente_clima, " +
            "fecha_descarga = now() " +
            "RETURNING id", connection);

        AgregarParametros(command, datos);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<DatosClimaticos?> ObtenerPorParcelaYFecha(int parcelaId, DateTime fecha)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasDato} FROM datos_climaticos WHERE parcela_id = @ParcelaId AND fecha = @Fecha",
            connection);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);
        command.Parameters.AddWithValue("@Fecha", FechasUtc.ADateOnly(fecha));

        await connection.OpenAsync();
        using var reader = await command.ExecuteReaderAsync();

        return await reader.ReadAsync() ? MapDato(reader) : null;
    }

    public async Task<List<DatosClimaticos>> ObtenerUltimosDatos(int parcelaId, int dias = 7)
    {
        var lista = new List<DatosClimaticos>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasDato} FROM datos_climaticos " +
            "WHERE parcela_id = @ParcelaId ORDER BY fecha DESC LIMIT @Dias", connection);
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

    public async Task<List<DatosClimaticos>> ObtenerPorRangoFechas(int parcelaId, DateTime desde, DateTime hasta)
    {
        var lista = new List<DatosClimaticos>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasDato} FROM datos_climaticos " +
            "WHERE parcela_id = @ParcelaId AND fecha BETWEEN @Desde AND @Hasta " +
            "ORDER BY fecha DESC", connection);
        command.Parameters.AddWithValue("@ParcelaId", parcelaId);
        command.Parameters.AddWithValue("@Desde", FechasUtc.ADateOnly(desde));
        command.Parameters.AddWithValue("@Hasta", FechasUtc.ADateOnly(hasta));

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

    private static void AgregarParametros(NpgsqlCommand command, DatosClimaticos datos)
    {
        command.Parameters.AddWithValue("@ParcelaId", datos.ParcelaId);
        command.Parameters.AddWithValue("@Fecha", FechasUtc.ADateOnly(datos.Fecha));
        command.Parameters.AddWithValue("@TMedia", (object?)datos.TemperaturaMedia ?? DBNull.Value);
        command.Parameters.AddWithValue("@TMax", (object?)datos.TemperaturaMax ?? DBNull.Value);
        command.Parameters.AddWithValue("@TMin", (object?)datos.TemperaturaMin ?? DBNull.Value);
        command.Parameters.AddWithValue("@Precipitacion", (object?)datos.Precipitacion ?? DBNull.Value);
        command.Parameters.AddWithValue("@Humedad", (object?)datos.HumedadRelativa ?? DBNull.Value);
        command.Parameters.AddWithValue("@Viento", (object?)datos.VientoVelocidad ?? DBNull.Value);
        command.Parameters.AddWithValue("@Radiacion", (object?)datos.RadiacionSolar ?? DBNull.Value);
        command.Parameters.AddWithValue("@Fuente", datos.FuenteClima);
    }

    private static DatosClimaticos MapDato(NpgsqlDataReader reader)
    {
        return new DatosClimaticos
        {
            Id = reader.GetInt32(0),
            ParcelaId = reader.GetInt32(1),
            Fecha = FechasUtc.DeDateOnly(reader.GetFieldValue<DateOnly>(2)),
            TemperaturaMedia = reader.IsDBNull(3) ? null : reader.GetDecimal(3),
            TemperaturaMax = reader.IsDBNull(4) ? null : reader.GetDecimal(4),
            TemperaturaMin = reader.IsDBNull(5) ? null : reader.GetDecimal(5),
            Precipitacion = reader.IsDBNull(6) ? null : reader.GetDecimal(6),
            HumedadRelativa = reader.IsDBNull(7) ? null : reader.GetDecimal(7),
            VientoVelocidad = reader.IsDBNull(8) ? null : reader.GetDecimal(8),
            RadiacionSolar = reader.IsDBNull(9) ? null : reader.GetDecimal(9),
            FuenteClima = reader.GetString(10),
            FechaDescarga = reader.GetDateTime(11)
        };
    }
}
