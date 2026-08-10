using System.Security.Cryptography;
using System.Text;

namespace WebApi.Implementation.Security;

public static class HashPin
{
    public static string GenerateSalt()
    {
        // para generar hash difernte si dos personas usan el mismo pin
        var randomBytes = RandomNumberGenerator.GetBytes(16);
        return Convert.ToBase64String(randomBytes);
    }

    public static string CalculateHash(string pin, string salt)
    {
        var combined = Encoding.UTF8.GetBytes(pin + salt);
        var hashBytes = SHA256.HashData(combined);
        return Convert.ToBase64String(hashBytes);
    }

    public static bool Verify(string pin, string salt, string hashGuardado)
    {
        var hashCalculado = CalculateHash(pin, salt);

        var bytesCalculado = Encoding.UTF8.GetBytes(hashCalculado);
        var bytesGuardado = Encoding.UTF8.GetBytes(hashGuardado);

        return CryptographicOperations.FixedTimeEquals(bytesCalculado, bytesGuardado);
    }
}