using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Implementation.Security;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class UsuarioService : IUsuarioService
{
    private readonly ConnectionBD _connectionBD;

    public UsuarioService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<int> Registrar(Usuario usuario)
    {
        var salt = HashPin.GenerateSalt();
        var hash = HashPin.CalculateHash(usuario.PinHash, salt); 

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "INSERT INTO Usuarios (Nombre, Telefono, PinHash, PinSalt) " +
            "OUTPUT INSERTED.Id " +
            "VALUES (@Nombre, @Telefono, @PinHash, @PinSalt)", connection);

        command.Parameters.AddWithValue("@Nombre", usuario.Nombre);
        command.Parameters.AddWithValue("@Telefono", usuario.Telefono);
        command.Parameters.AddWithValue("@PinHash", hash);
        command.Parameters.AddWithValue("@PinSalt", salt);

        await connection.OpenAsync();
        var result = await command.ExecuteScalarAsync();
        return Convert.ToInt32(result);
    }

    public async Task<Usuario?> Autenticar(string telefono, string pin)
    {
        var usuario = await ObtenerPorTelefono(telefono);
        if (usuario is null)
            return null;

        var esValido = HashPin.Verify(pin, usuario.PinSalt, usuario.PinHash);
        return esValido ? usuario : null;
    }

    public async Task<Usuario?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, Nombre, Telefono, PinHash, PinSalt, FechaRegistro, Activo, EsAdmin " +
            "FROM Usuarios WHERE Id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapUsuario(lector) : null;
    }

    public async Task<Usuario?> ObtenerPorTelefono(string telefono)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, Nombre, Telefono, PinHash, PinSalt, FechaRegistro, Activo, EsAdmin " +
            "FROM Usuarios WHERE Telefono = @Telefono", connection);
        command.Parameters.AddWithValue("@Telefono", telefono);

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
            Telefono = lector.GetString(2),
            PinHash = lector.GetString(3),
            PinSalt = lector.GetString(4),
            FechaRegistro = lector.GetDateTime(5),
            Activo = lector.GetBoolean(6),
            EsAdmin = lector.GetBoolean(7)
        };
    }
}