using WebApi.Models;

namespace WebApi.Interface;

public interface IBitacoraService {
    Task<int> RegistrarEntrada(BitacoraCampo entrada);
    Task<List<BitacoraCampo>> ObtenerHistorial(int usuarioId);
    Task<bool> MarcarAccionCompletada(int entradaId, int numeroAccion);
    Task<string> CompartirResumen(int usuarioId);
}