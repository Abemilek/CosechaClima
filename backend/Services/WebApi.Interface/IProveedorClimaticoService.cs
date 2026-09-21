using WebApi.Models;

namespace WebApi.Interface;

public interface IProveedorClimaticoService
{
    Task<DatosClimaticos?> ObtenerYGuardarDatosActuales (int parcelaId, decimal latitud, decimal longitud);
    Task<List<PronosticoPublico>> ObtenerPronosticoPublico (decimal latitud, decimal longitud);
}
