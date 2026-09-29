using System.ComponentModel.DataAnnotations;

namespace WebApi.Dto;

public class UsuarioAdminDto
{
    public int Id { get; set; }
    public string Nombre { get; set; } = string.Empty;
    public string Email { get; set; } = string.Empty;
    public string Proveedor { get; set; } = string.Empty;
    public DateTime FechaRegistro { get; set; }
    public bool Activo { get; set; }
    public bool EsAdmin { get; set; }
}

public class CambiarRolDto
{
    [Required]
    public bool EsAdmin { get; set; }
}

public class CambiarEstadoDto
{
    [Required]
    public bool Activo { get; set; }
}
