using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class RegisterDto
{
    [Required, MaxLength(100)]
    public string Nombre { get; set; } = string.Empty;

    [Required, EmailAddress(ErrorMessage = "el correo no tiene un formato valido")]
    [MaxLength(256)]
    public string Email { get; set; } = string.Empty;

    [Required, MinLength(8, ErrorMessage = "la contrasena debe tener al menos 8 caracteres")]
    [MaxLength(128)]
    public string Password { get; set; } = string.Empty;
}

public class LoginDto
{
    [Required, EmailAddress(ErrorMessage = "el correo no tiene un formato valido")]
    public string Email { get; set; } = string.Empty;

    [Required]
    public string Password { get; set; } = string.Empty;
}

public class GoogleLoginDto
{
    [Required(ErrorMessage = "falta el idToken de Google")]
    public string IdToken { get; set; } = string.Empty;
}

public class RefreshDto
{
    [Required, MaxLength(200)]
    public string RefreshToken { get; set; } = string.Empty;
}

public class LoginResponseDto
{
    /// <summary>Access token (JWT) de vida corta.</summary>
    public string Token { get; set; } = string.Empty;

    /// <summary>Refresh token de un solo uso (movil). En web va en una cookie HttpOnly y este campo es null.</summary>
    public string? RefreshToken { get; set; }

    /// <summary>Segundos de vida del access token.</summary>
    public int ExpiraEnSegundos { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? FotoUrl { get; set; }
    public bool EsAdmin { get; set; }
}
