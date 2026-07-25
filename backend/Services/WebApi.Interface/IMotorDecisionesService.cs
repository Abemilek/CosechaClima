using WebApi.Models;

namespace WebApi.Interface;

public interface IMotorDecisionesService {
    Task<Alerta> CalcularSemaforo (int parcelaId);
}