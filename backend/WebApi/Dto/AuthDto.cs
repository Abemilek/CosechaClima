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

public class LoginResponseDto
{
    public string Token { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string? FotoUrl { get; set; }
    public bool EsAdmin { get; set; }
}
