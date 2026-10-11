using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Configuration;
using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Interface;

namespace WebApi.Implementation.Security;

/// <summary>
/// Refresh tokens opacos (32 bytes aleatorios) de un solo uso con rotacion.
/// - En la base solo se guarda su SHA-256.
/// - Cada canje entrega un token nuevo hijo del anterior (misma familia).
/// - Reutilizar un token ya canjeado revoca toda la familia (posible robo).
/// - Tolerancia a respuestas perdidas: si el hijo nunca se uso, el padre puede reintentar
///   (importante con conexiones rurales inestables: sin esto un corte de red cerraria la sesion).
/// - Duracion deslizante (Jwt:RefreshDays, 30 por defecto) con tope absoluto por familia (Jwt:RefreshMaxDays, 180).
/// </summary>
public class RefreshTokenService : IRefreshTokenService
{
    private readonly ConnectionBD _connectionBD;
    private readonly int _dias;
    private readonly int _diasMaximos;

    public RefreshTokenService(ConnectionBD connectionBD, IConfiguration configuracion)
    {
        _connectionBD = connectionBD;
        _dias = int.TryParse(configuracion["Jwt:RefreshDays"], out var d) && d > 0 ? d : 30;
        _diasMaximos = int.TryParse(configuracion["Jwt:RefreshMaxDays"], out var m) && m >= _dias ? m : 180;
    }

    public async Task<string> EmitirAsync(int usuarioId, string cliente)
    {
        var token = GenerarToken();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO refresh_tokens (usuario_id, familia_id, familia_inicio, token_hash, cliente, expira_en) " +
            "VALUES (@Usuario, @Familia, now(), @Hash, @Cliente, now() + (@Dias * interval '1 day'))",
            connection);
        command.Parameters.AddWithValue("@Usuario", usuarioId);
        command.Parameters.AddWithValue("@Familia", Guid.NewGuid());
        command.Parameters.AddWithValue("@Hash", Hashear(token));
        command.Parameters.AddWithValue("@Cliente", cliente);
        command.Parameters.AddWithValue("@Dias", _dias);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
        return token;
    }

    public async Task<RotacionRefresh?> RotarAsync(string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken) || refreshToken.Length > 200)
            return null;

        using var connection = _connectionBD.CrearConexion();
        await connection.OpenAsync();
        using var transaccion = await connection.BeginTransactionAsync();

        long id;
        int usuarioId;
        Guid familiaId;
        DateTime familiaInicio;
        string cliente;
        bool expirado;
        bool usado;
        bool revocado;
        bool usuarioActivo;

        // FOR UPDATE: serializa canjes simultaneos del mismo token.
        using (var buscar = new NpgsqlCommand(
            "SELECT t.id, t.usuario_id, t.familia_id, t.familia_inicio, t.cliente, " +
            "t.expira_en <= now(), t.usado_en IS NOT NULL, t.revocado_en IS NOT NULL, u.activo " +
            "FROM refresh_tokens t JOIN usuarios u ON u.id = t.usuario_id " +
            "WHERE t.token_hash = @Hash FOR UPDATE OF t", connection, transaccion))
        {
            buscar.Parameters.AddWithValue("@Hash", Hashear(refreshToken));
            using var lector = await buscar.ExecuteReaderAsync();
            if (!await lector.ReadAsync())
            {
                return null;
            }

            id = lector.GetInt64(0);
            usuarioId = lector.GetInt32(1);
            familiaId = lector.GetGuid(2);
            familiaInicio = lector.GetDateTime(3);
            cliente = lector.GetString(4);
            expirado = lector.GetBoolean(5);
            usado = lector.GetBoolean(6);
            revocado = lector.GetBoolean(7);
            usuarioActivo = lector.GetBoolean(8);
        }

        if (revocado || !usuarioActivo)
        {
            // Token revocado que reaparece, o cuenta desactivada: se cierra toda la familia.
            await RevocarFamiliaAsync(connection, transaccion, familiaId);
            await transaccion.CommitAsync();
            return null;
        }

        if (expirado)
        {
            return null;
        }

        if (usado)
        {
            long? hijoId = null;
            bool hijoUsado = true;
            bool hijoRevocado = true;

            using (var buscarHijo = new NpgsqlCommand(
                "SELECT id, usado_en IS NOT NULL, revocado_en IS NOT NULL FROM refresh_tokens " +
                "WHERE padre_id = @Padre ORDER BY id DESC LIMIT 1 FOR UPDATE", connection, transaccion))
            {
                buscarHijo.Parameters.AddWithValue("@Padre", id);
                using var lector = await buscarHijo.ExecuteReaderAsync();
                if (await lector.ReadAsync())
                {
                    hijoId = lector.GetInt64(0);
                    hijoUsado = lector.GetBoolean(1);
                    hijoRevocado = lector.GetBoolean(2);
                }
            }

            if (hijoId is null || hijoUsado || hijoRevocado)
            {
                // El token ya se canjeo y su hijo ya avanzo: reutilizacion => robo probable.
                await RevocarFamiliaAsync(connection, transaccion, familiaId);
                await transaccion.CommitAsync();
                return null;
            }

            // Reintento legitimo (la respuesta anterior se perdio): se anula el hijo huerfano.
            using var anular = new NpgsqlCommand(
                "UPDATE refresh_tokens SET revocado_en = now() WHERE id = @Id", connection, transaccion);
            anular.Parameters.AddWithValue("@Id", hijoId.Value);
            await anular.ExecuteNonQueryAsync();
        }
        else
        {
            using var marcar = new NpgsqlCommand(
                "UPDATE refresh_tokens SET usado_en = now() WHERE id = @Id", connection, transaccion);
            marcar.Parameters.AddWithValue("@Id", id);
            await marcar.ExecuteNonQueryAsync();
        }

        var nuevoToken = GenerarToken();
        bool vigente;
        using (var insertar = new NpgsqlCommand(
            "INSERT INTO refresh_tokens (usuario_id, familia_id, familia_inicio, padre_id, token_hash, cliente, expira_en) " +
            "VALUES (@Usuario, @Familia, @Inicio, @Padre, @Hash, @Cliente, " +
            "LEAST(now() + (@Dias * interval '1 day'), @Inicio::timestamptz + (@Maximo * interval '1 day'))) " +
            "RETURNING expira_en > now()", connection, transaccion))
        {
            insertar.Parameters.AddWithValue("@Usuario", usuarioId);
            insertar.Parameters.AddWithValue("@Familia", familiaId);
            insertar.Parameters.AddWithValue("@Inicio", familiaInicio);
            insertar.Parameters.AddWithValue("@Padre", id);
            insertar.Parameters.AddWithValue("@Hash", Hashear(nuevoToken));
            insertar.Parameters.AddWithValue("@Cliente", cliente);
            insertar.Parameters.AddWithValue("@Dias", _dias);
            insertar.Parameters.AddWithValue("@Maximo", _diasMaximos);
            vigente = (bool)(await insertar.ExecuteScalarAsync())!;
        }

        if (!vigente)
        {
            // La familia llego a su tope absoluto: hay que volver a iniciar sesion.
            await transaccion.RollbackAsync();
            return null;
        }

        await transaccion.CommitAsync();
        return new RotacionRefresh(usuarioId, cliente, nuevoToken);
    }

    public async Task RevocarFamiliaAsync(string refreshToken)
    {
        if (string.IsNullOrWhiteSpace(refreshToken) || refreshToken.Length > 200)
            return;

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE refresh_tokens SET revocado_en = now() " +
            "WHERE revocado_en IS NULL AND familia_id = " +
            "(SELECT familia_id FROM refresh_tokens WHERE token_hash = @Hash)", connection);
        command.Parameters.AddWithValue("@Hash", Hashear(refreshToken));

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task<int> LimpiarExpiradosAsync()
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "DELETE FROM refresh_tokens WHERE expira_en < now() - interval '7 days'", connection);

        await connection.OpenAsync();
        return await command.ExecuteNonQueryAsync();
    }

    private static async Task RevocarFamiliaAsync(NpgsqlConnection conexion, NpgsqlTransaction transaccion, Guid familiaId)
    {
        using var command = new NpgsqlCommand(
            "UPDATE refresh_tokens SET revocado_en = now() WHERE familia_id = @Familia AND revocado_en IS NULL",
            conexion, transaccion);
        command.Parameters.AddWithValue("@Familia", familiaId);
        await command.ExecuteNonQueryAsync();
    }

    private static string GenerarToken() => Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(32));

    // El token ya tiene 256 bits de entropia: un hash rapido (SHA-256) es suficiente y permite buscarlo por indice.
    private static byte[] Hashear(string token) => SHA256.HashData(Encoding.UTF8.GetBytes(token));
}
