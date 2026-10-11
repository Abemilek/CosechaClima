using Npgsql;
using WebApi.Implementation.Connection;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class UsuarioService : IUsuarioService
{
    private const string ColumnasUsuario =
        "id, nombre, email, google_uid, password_hash, password_salt, " +
        "proveedor, foto_url, fecha_registro, activo, es_admin";

    private readonly ConnectionBD _connectionBD;

    public UsuarioService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> RegistrarConEmail(Usuario usuario, string passwordEnTextoPlano)
    {
        var salt = HashPassword.GenerateSalt();
        var hash = HashPassword.CalculateHash(passwordEnTextoPlano, salt);

        usuario.PasswordSalt = salt;
        usuario.PasswordHash = hash;
        usuario.Proveedor = ProveedorAuth.Email;

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO usuarios (nombre, email, password_hash, password_salt, proveedor) " +
            "VALUES (@Nombre, @Email, @PasswordHash, @PasswordSalt, @Proveedor) " +
            "RETURNING id",
            connection);

        command.Parameters.AddWithValue("@Nombre", usuario.Nombre);
        command.Parameters.AddWithValue("@Email", usuario.Email.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("@PasswordHash", usuario.PasswordHash);
        command.Parameters.AddWithValue("@PasswordSalt", usuario.PasswordSalt);
        command.Parameters.AddWithValue("@Proveedor", (short)ProveedorAuth.Email);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<Usuario?> AutenticarConEmail(string email, string password)
    {
        var usuario = await ObtenerPorEmail(email);

        if (usuario is null || !usuario.Activo)
            return null;

        if (usuario.Proveedor != ProveedorAuth.Email
            || string.IsNullOrEmpty(usuario.PasswordHash)
            || string.IsNullOrEmpty(usuario.PasswordSalt))
        {
            return null;
        }

        var esValido = HashPassword.Verify(password, usuario.PasswordSalt, usuario.PasswordHash);
        return esValido ? usuario : null;
    }

    public async Task<Usuario> ObtenerOCrearDesdeGoogle(UsuarioGoogle datosGoogle)
    {
        var email = datosGoogle.Email.Trim().ToLowerInvariant();

        var porUid = await ObtenerPorGoogleUid(datosGoogle.Uid);
        if (porUid is not null)
        {
            await ActualizarPerfilGoogle(porUid.Id, datosGoogle);
            porUid.Nombre = datosGoogle.Nombre;
            porUid.FotoUrl = datosGoogle.FotoUrl;
            return porUid;
        }

        var porEmail = await ObtenerPorEmail(email);
        if (porEmail is not null)
        {
            await VincularGoogle(porEmail.Id, datosGoogle);
            porEmail.GoogleUid = datosGoogle.Uid;
            porEmail.FotoUrl = datosGoogle.FotoUrl;
            return porEmail;
        }

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "INSERT INTO usuarios (nombre, email, google_uid, proveedor, foto_url) " +
            "VALUES (@Nombre, @Email, @GoogleUid, @Proveedor, @FotoUrl) " +
            "RETURNING id",
            connection);

        command.Parameters.AddWithValue("@Nombre", datosGoogle.Nombre);
        command.Parameters.AddWithValue("@Email", email);
        command.Parameters.AddWithValue("@GoogleUid", datosGoogle.Uid);
        command.Parameters.AddWithValue("@Proveedor", (short)ProveedorAuth.Google);
        command.Parameters.AddWithValue("@FotoUrl", (object?)datosGoogle.FotoUrl ?? DBNull.Value);

        await connection.OpenAsync();
        var id = Convert.ToInt32(await command.ExecuteScalarAsync());

        return new Usuario
        {
            Id = id,
            Nombre = datosGoogle.Nombre,
            Email = email,
            GoogleUid = datosGoogle.Uid,
            Proveedor = ProveedorAuth.Google,
            FotoUrl = datosGoogle.FotoUrl,
            Activo = true,
            EsAdmin = false
        };
    }

    private async Task ActualizarPerfilGoogle(int usuarioId, UsuarioGoogle datosGoogle)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE usuarios SET nombre = @Nombre, foto_url = @FotoUrl WHERE id = @Id",
            connection);

        command.Parameters.AddWithValue("@Nombre", datosGoogle.Nombre);
        command.Parameters.AddWithValue("@FotoUrl", (object?)datosGoogle.FotoUrl ?? DBNull.Value);
        command.Parameters.AddWithValue("@Id", usuarioId);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    private async Task VincularGoogle(int usuarioId, UsuarioGoogle datosGoogle)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE usuarios SET google_uid = @GoogleUid, foto_url = @FotoUrl WHERE id = @Id",
            connection);

        command.Parameters.AddWithValue("@GoogleUid", datosGoogle.Uid);
        command.Parameters.AddWithValue("@FotoUrl", (object?)datosGoogle.FotoUrl ?? DBNull.Value);
        command.Parameters.AddWithValue("@Id", usuarioId);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    private async Task<Usuario?> ObtenerPorGoogleUid(string googleUid)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasUsuario} FROM usuarios WHERE google_uid = @GoogleUid", connection);
        command.Parameters.AddWithValue("@GoogleUid", googleUid);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    public async Task MarcarComoAdmin(int usuarioId)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE usuarios SET es_admin = true WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@Id", usuarioId);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task<List<Usuario>> ListarTodos()
    {
        var lista = new List<Usuario>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasUsuario} FROM usuarios ORDER BY fecha_registro DESC, id DESC", connection);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
            lista.Add(MapUsuario(lector));

        return lista;
    }

    public async Task<bool> CambiarRol(int usuarioId, bool esAdmin)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE usuarios SET es_admin = @EsAdmin WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@EsAdmin", esAdmin);
        command.Parameters.AddWithValue("@Id", usuarioId);

        await connection.OpenAsync();
        var filas = await command.ExecuteNonQueryAsync();
        return filas > 0;
    }

    public async Task<bool> CambiarActivo(int usuarioId, bool activo)
    {
        using var connection = _connectionBD.CrearConexion();
        await connection.OpenAsync();

        // Al desactivar una cuenta tambien se revocan sus refresh tokens, en la misma transaccion:
        // asi no puede renovar sesion (el access token vigente expira solo en minutos).
        using var transaccion = await connection.BeginTransactionAsync();

        int filas;
        using (var command = new NpgsqlCommand(
            "UPDATE usuarios SET activo = @Activo WHERE id = @Id", connection, transaccion))
        {
            command.Parameters.AddWithValue("@Activo", activo);
            command.Parameters.AddWithValue("@Id", usuarioId);
            filas = await command.ExecuteNonQueryAsync();
        }

        if (!activo && filas > 0)
        {
            using var revocar = new NpgsqlCommand(
                "UPDATE refresh_tokens SET revocado_en = now() " +
                "WHERE usuario_id = @Id AND revocado_en IS NULL", connection, transaccion);
            revocar.Parameters.AddWithValue("@Id", usuarioId);
            await revocar.ExecuteNonQueryAsync();
        }

        await transaccion.CommitAsync();
        return filas > 0;
    }

    public async Task<Usuario?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasUsuario} FROM usuarios WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    public async Task<Usuario?> ObtenerPorEmail(string email)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasUsuario} FROM usuarios WHERE email = @Email", connection);
        command.Parameters.AddWithValue("@Email", email.Trim().ToLowerInvariant());

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    private static Usuario MapUsuario(NpgsqlDataReader lector)
    {
        return new Usuario
        {
            Id = lector.GetInt32(0),
            Nombre = lector.GetString(1),
            Email = lector.GetString(2),
            GoogleUid = lector.IsDBNull(3) ? null : lector.GetString(3),
            PasswordHash = lector.IsDBNull(4) ? null : lector.GetString(4),
            PasswordSalt = lector.IsDBNull(5) ? null : lector.GetString(5),
            Proveedor = (ProveedorAuth)lector.GetInt16(6),
            FotoUrl = lector.IsDBNull(7) ? null : lector.GetString(7),
            FechaRegistro = lector.GetDateTime(8),
            Activo = lector.GetBoolean(9),
            EsAdmin = lector.GetBoolean(10)
        };
    }
}
