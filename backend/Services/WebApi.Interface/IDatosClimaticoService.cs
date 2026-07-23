using WebApi.Models;

namespace WebApi.Interface;

public interface IDatosClimaticoService {
    Task<int> GuardarDatos (DatosClimaticos datos);
    Task<DatosClimaticos> ObtenerPorParcelaYFecha(int parcelaId, DateTime fecha);
    Task<List<DatosClimaticos>> ObtenerUltimosDatos (int parcelaId, int dias = 7);
    Task<List<DatosClimaticos>> ObtenerPrediccion (int parcelaId);
}
