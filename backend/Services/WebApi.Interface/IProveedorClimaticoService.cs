using WebApi.Models;

namespace WebApi.Interface;

public interface IProveedorClimaticoService
{
    Task<DatosClimaticos?> ObtenerYGuardarDatosActuales (int parcelaId, decimal latitud, decimal longitud);
}