using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;

namespace WebApi.Extensions;

public static class ControllerBaseExtensions
{
    public static int ObtenerUsuarioIdActual(this ControllerBase controller)
    {
        var valor = controller.User.FindFirstValue(ClaimTypes.NameIdentifier);

        if (valor is null || !int.TryParse(valor, out var usuarioId))
            throw new UnauthorizedAccessException("el token no contiene un identificador de usuario valido");

        return usuarioId;
    }   
}