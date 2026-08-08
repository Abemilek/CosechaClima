using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class RegisterDto
{
    [Required, MaxLength(100)]
    public string Nombre { get; set; } = string.Empty;

    // esto asume numeros de telefonos de nicaragua de 8 digitos
    [Required, RegularExpression(@"^\d{8}$", ErrorMessage = "el telefono debe tener 8 digitos")]
    public string Telefono { get; set; } = string.Empty;

    // y aqui se fuerza que sea de 4 dijitos el pin
    [Required, RegularExpression(@"^\d{4}$", ErrorMessage = "el pin debe ser de exactamente 4 digitos")]
    public string Pin { get; set; } = string.Empty;
}

public class LoginDto
{
    [Required]
    public string Telefono { get; set; } = string.Empty;

    [Required]
    public string Pin { get; set; } = string.Empty;
}

public class LoginResponseDto
{
    public string Token { get; set; } = string.Empty;
    public string Nombre { get; set; } = string.Empty;
}