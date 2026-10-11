namespace WebApi.Interface;

public sealed record RotacionRefresh(int UsuarioId, string Cliente, string NuevoToken);

public interface IRefreshTokenService
{
    /// <summary>Inicia una familia nueva de tokens (un inicio de sesion) y devuelve el token en claro.</summary>
    Task<string> EmitirAsync(int usuarioId, string cliente);

    /// <summary>
    /// Canjea un refresh token por uno nuevo (rotacion de un solo uso). Devuelve null si el token
    /// no existe, expiro, fue revocado o se detecto reutilizacion (en ese caso toda la familia se revoca).
    /// </summary>
    Task<RotacionRefresh?> RotarAsync(string refreshToken);

    /// <summary>Cierra la sesion: revoca toda la familia del token recibido.</summary>
    Task RevocarFamiliaAsync(string refreshToken);

    /// <summary>Borra tokens vencidos hace mas de 7 dias. Devuelve cuantos elimino.</summary>
    Task<int> LimpiarExpiradosAsync();
}
