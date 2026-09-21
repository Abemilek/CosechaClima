using System.Security.Cryptography;

namespace WebApi.Implementation.Security;

public static class HashPassword
{
    private const int Iteraciones = 600_000;
    private const int TamanoHashBytes = 32;
    private const int TamanoSaltBytes = 16;

    public static string GenerateSalt()
    {
        var randomBytes = RandomNumberGenerator.GetBytes(TamanoSaltBytes);
        return Convert.ToBase64String(randomBytes);
    }

    public static string CalculateHash(string password, string salt)
    {
        var saltBytes = Convert.FromBase64String(salt);

        var hashBytes = Rfc2898DeriveBytes.Pbkdf2(
            password: password,
            salt: saltBytes,
            iterations: Iteraciones,
            hashAlgorithm: HashAlgorithmName.SHA256,
            outputLength: TamanoHashBytes);

        return Convert.ToBase64String(hashBytes);
    }

    public static bool Verify(string password, string salt, string hashGuardado)
    {
        var hashCalculado = CalculateHash(password, salt);

        var bytesCalculado = Convert.FromBase64String(hashCalculado);
        var bytesGuardado = Convert.FromBase64String(hashGuardado);

        return CryptographicOperations.FixedTimeEquals(bytesCalculado, bytesGuardado);
    }
}
