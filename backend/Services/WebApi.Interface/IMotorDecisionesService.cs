using WebApi.Models;

namespace WebApi.Interface;

public interface IMotorDecisionesService {
    Task<Alerta> CalcularSemaforo (int parcelaId);
    Task<ResumenSemanal> CalcularResumenSemanal (int parcelaId, int dias = 7);
}