using WebApi.Models;

namespace WebApi.Interface;

public interface INasaPowerService
{
    Task<DatosClimaticos?> ObtenerYGuardarDatosActuales (int parcelaId, decimal latitud, decimal longitud);
}