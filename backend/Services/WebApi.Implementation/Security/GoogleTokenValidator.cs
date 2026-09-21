using Google.Apis.Auth;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation.Security;

public class GoogleTokenValidator : IGoogleTokenValidator
{
    private readonly IConfiguration _configuration;
    private readonly ILogger<GoogleTokenValidator> _logger;

    public GoogleTokenValidator(
        IConfiguration configuration,
        ILogger<GoogleTokenValidator> logger)
    {
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<UsuarioGoogle?> ValidarIdToken(string idToken)
    {
        var clientIds = _configuration
            .GetSection("GoogleAuth:ClientIds")
            .GetChildren()
            .Select(hijo => hijo.Value)
            .Where(valor => !string.IsNullOrWhiteSpace(valor))
            .Select(valor => valor!)
            .ToArray();

        if (clientIds.Length == 0)
        {
            _logger.LogError(
                "GoogleAuth:ClientIds no está configurado -- no se puede validar " +
                "el ID Token. Definí GOOGLE_CLIENT_ID_ANDROID / _IOS / _WEB " +
                "(ver .env.example).");
            return null;
        }

        try
        {
            var configuracion = new GoogleJsonWebSignature.ValidationSettings
            {
                Audience = clientIds
            };

            var payload = await GoogleJsonWebSignature.ValidateAsync(idToken, configuracion);

            if (!payload.EmailVerified)
            {
                _logger.LogWarning("ID Token de Google con email sin verificar: {Subject}", payload.Subject);
                return null;
            }

            return new UsuarioGoogle
            {
                Uid = payload.Subject,
                Email = payload.Email,
                Nombre = string.IsNullOrWhiteSpace(payload.Name)
                    ? payload.Email.Split('@')[0]
                    : payload.Name,
                FotoUrl = payload.Picture
            };
        }
        catch (InvalidJwtException ex)
        {
            _logger.LogWarning(ex, "ID Token de Google inválido");
            return null;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error inesperado al validar ID Token de Google");
            return null;
        }
    }
}