using System.Security.Cryptography;
using System.Text;

namespace WebApi.Implementation.Security;

public static class HashPin
{
    private const int Iteraciones = 210_000;
    private const int TamanoHashBytes = 32;

    public static string GenerateSalt()
    {
        // para generar hash difernte si dos personas usan el mismo pin
        var randomBytes = RandomNumberGenerator.GetBytes(16);
        return Convert.ToBase64String(randomBytes);
    }

    public static string CalculateHash(string pin, string salt)
    {
        var saltBytes = Convert.FromBase64String(salt);

        var hashBytes = Rfc2898DeriveBytes.Pbkdf2(
            password: pin,
            salt: saltBytes,
            iterations: Iteraciones,
            hashAlgorithm: HashAlgorithmName.SHA256,
            outputLength: TamanoHashBytes);

        return Convert.ToBase64String(hashBytes);
    }

    public static bool Verify(string pin, string salt, string hashGuardado)
    {
        var hashCalculado = CalculateHash(pin, salt);

        var bytesCalculado = Convert.FromBase64String(hashCalculado);
        var bytesGuardado = Convert.FromBase64String(hashGuardado);

        return CryptographicOperations.FixedTimeEquals(bytesCalculado, bytesGuardado);
    }
}