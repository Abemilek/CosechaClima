using System.Threading.Tasks;
using System.Threading.Tasks.Dataflow;
using CosechaClima.Models;

namespace CosechaClima.Interface;

public interface IParcelaService {
    Task<int> Registrar (Parcela parcela);
    Task<Parcela> ObtenerPorId (int id);
    Task<List<Parcela>> ObtenerPorProductor(int productorId);
    Task<bool> ActualizarEtapa (int parcelaId, int etapaId);
    // marcar la parcela como inactiva
    Task<bool> Eliminar(int id);
}