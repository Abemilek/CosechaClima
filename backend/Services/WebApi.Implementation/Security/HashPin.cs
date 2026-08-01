using System.Security.Cryptography;
using System.Text;

namespace WebApi.Implementation.Security;

public static class HashPin
{
    public static string GenerateSalt()
    {
        // para generar hash difernte si dos personas usan el mismo pin
        var bytesAleatorios = RandomNumberGenerator.GetBytes(16);
        return Convert.ToBase64String(bytesAleatorios);
    }

    public static string CalculateHash(string pin, string salt)
    {
        var combinado = Encoding.UTF8.GetBytes(pin + salt);
        var hashBytes = SHA256.HashData(combinado);
        return Convert.ToBase64String(hashBytes);
    }

    public static bool Verify(string pin, string salt, string hashGuardado)
    {
        return CalculateHash(pin, salt) == hashGuardado;
    }
}