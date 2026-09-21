using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class UsuarioService : IUsuarioService
{
    private const string ColumnasUsuario =
        "Id, Nombre, Email, GoogleUid, PasswordHash, PasswordSalt, " +
        "Proveedor, FotoUrl, FechaRegistro, Activo, EsAdmin";

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
        using var command = new SqlCommand(
            "INSERT INTO Usuarios (Nombre, Email, PasswordHash, PasswordSalt, Proveedor) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@Nombre, @Email, @PasswordHash, @PasswordSalt, @Proveedor)",
            connection);

        command.Parameters.AddWithValue("@Nombre", usuario.Nombre);
        command.Parameters.AddWithValue("@Email", usuario.Email.Trim().ToLowerInvariant());
        command.Parameters.AddWithValue("@PasswordHash", usuario.PasswordHash);
        command.Parameters.AddWithValue("@PasswordSalt", usuario.PasswordSalt);
        command.Parameters.AddWithValue("@Proveedor", (byte)ProveedorAuth.Email);

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
        using var command = new SqlCommand(
            "INSERT INTO Usuarios (Nombre, Email, GoogleUid, Proveedor, FotoUrl) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@Nombre, @Email, @GoogleUid, @Proveedor, @FotoUrl)",
            connection);

        command.Parameters.AddWithValue("@Nombre", datosGoogle.Nombre);
        command.Parameters.AddWithValue("@Email", email);
        command.Parameters.AddWithValue("@GoogleUid", datosGoogle.Uid);
        command.Parameters.AddWithValue("@Proveedor", (byte)ProveedorAuth.Google);
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
        using var command = new SqlCommand(
            "UPDATE Usuarios SET Nombre = @Nombre, FotoUrl = @FotoUrl WHERE Id = @Id",
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
        using var command = new SqlCommand(
            "UPDATE Usuarios SET GoogleUid = @GoogleUid, FotoUrl = @FotoUrl WHERE Id = @Id",
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
        using var command = new SqlCommand(
            $"SELECT {ColumnasUsuario} FROM Usuarios WHERE GoogleUid = @GoogleUid", connection);
        command.Parameters.AddWithValue("@GoogleUid", googleUid);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    public async Task MarcarComoAdmin(int usuarioId)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "UPDATE Usuarios SET EsAdmin = 1 WHERE Id = @Id", connection);
        command.Parameters.AddWithValue("@Id", usuarioId);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task<Usuario?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            $"SELECT {ColumnasUsuario} FROM Usuarios WHERE Id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    public async Task<Usuario?> ObtenerPorEmail(string email)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            $"SELECT {ColumnasUsuario} FROM Usuarios WHERE Email = @Email", connection);
        command.Parameters.AddWithValue("@Email", email.Trim().ToLowerInvariant());

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    private static Usuario MapUsuario(SqlDataReader lector)
    {
        return new Usuario
        {
            Id = lector.GetInt32(0),
            Nombre = lector.GetString(1),
            Email = lector.GetString(2),
            GoogleUid = lector.IsDBNull(3) ? null : lector.GetString(3),
            PasswordHash = lector.IsDBNull(4) ? null : lector.GetString(4),
            PasswordSalt = lector.IsDBNull(5) ? null : lector.GetString(5),
            Proveedor = (ProveedorAuth)lector.GetByte(6),
            FotoUrl = lector.IsDBNull(7) ? null : lector.GetString(7),
            FechaRegistro = lector.GetDateTime(8),
            Activo = lector.GetBoolean(9),
            EsAdmin = lector.GetBoolean(10)
        };
    }
}
