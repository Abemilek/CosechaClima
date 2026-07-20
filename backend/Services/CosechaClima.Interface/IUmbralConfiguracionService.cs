using System.Threading.Tasks;
using CosechaClima.Models;

namespace CosechaClima.Interface;

public interface IUmbralConfiguracionService {
    Task<int> CrearOActualizar (UmbralConfiguracion Umbral);
    Task<UmbralConfiguracion?> ObtenerPorProductor (int productorId);
    Task<bool> ActualizarUmbrales (int id, int? lluvia, int? viento, int? canicula);
}

