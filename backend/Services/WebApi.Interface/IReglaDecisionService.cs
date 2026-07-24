using WebApi.Models;

namespace WebApi.Interface;

public interface IReglaDecisionService {
    Task<List<ReglaDecision>> ObtenerTodas();
    Task SembrarReglasIniciales();
}