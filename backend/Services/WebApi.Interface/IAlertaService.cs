using WebApi.Models;

namespace WebApi.Interface;

public interface IAlertaService {
    Task<int> GuardarOActualizar(Alerta alerta);
    Task<Alerta?> ObtenerPorParcelaYFecha (int parcelaId, DateTime fecha);
    Task<List<Alerta>> ObtenerRecientes(int limite);
}