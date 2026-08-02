namespace WebApi.Dto;

public class RegisterDto
{
    public string Nombre {get; set; } = string.Empty;
    public string Telefono {get; set; } = string.Empty;
    public string Pin {get; set; } = string.Empty;
}

public class LoginDto
{
    public string Telefono {get; set; } = string.Empty;
    public string Pin {get; set; } = string.Empty;
}

public class LoginResponseDto
{
    public string Token {get; set;} = string.Empty;
    public String Nombre {get; set; } = string.Empty;
}