using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class MotorDecisionesService : IMotorDecisionesService
{
    private readonly IParcelaService _parcelaService;
    private readonly IUmbralConfiguracionService _umbralService;
    private readonly IDatosClimaticoService _datosClimaticoService;
    private readonly IReglaDecisionService _reglaDecisionService;
    private readonly IAlertaService _alertaService;
    private readonly IEtapaFenologicaService _etapaFenologicaService;

    public MotorDecisionesService(
        IParcelaService parcelaService,
        IUmbralConfiguracionService umbralService,
        IDatosClimaticoService datosClimaticoService,
        IReglaDecisionService reglaDecisionService,
        IAlertaService alertaService,
        IEtapaFenologicaService etapaFenologicaService)
    {
        _parcelaService = parcelaService;
        _umbralService = umbralService;
        _datosClimaticoService = datosClimaticoService;
        _reglaDecisionService = reglaDecisionService;
        _alertaService = alertaService;
        _etapaFenologicaService = etapaFenologicaService;
    }

    public async Task<Alerta> CalcularSemaforo(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId)
            ?? throw new InvalidOperationException($"No existe la parcela {parcelaId}");

        var etapaFenologicaId = parcela.EtapaFenologicaId
            ?? (await _etapaFenologicaService.CalcularDesdeFecha(parcela.FechaSiembra)).Id;

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? throw new InvalidOperationException("el usuario no tiene umbrales configurados");

        var datosRecientes = await _datosClimaticoService.ObtenerUltimosDatos(
            parcelaId, dias: umbrales.CaniculaDias);

        if (datosRecientes.Count == 0)
            throw new InvalidOperationException("no hay datos climaticos disponibles para esta parcela");

        var datoMasReciente = datosRecientes[0];
        var eventoClimaticoId = DetermineActiveEvent(datoMasReciente, datosRecientes, umbrales);

        var rule = await _reglaDecisionService.ObtenerPorClave(
    eventoClimaticoId, parcela.CultivoId, parcela.EtapaFenologicaId!.Value, parcela.TipoSueloId);

if (rule is null)
    throw new InvalidOperationException(
        $"No existe una regla para eventos={eventoClimaticoId}, Cultivo={parcela.CultivoId}, " +
        $"Etapa={parcela.EtapaFenologicaId}, Suelo={parcela.TipoSueloId}. Revisar seed de reglas decision");

        var alert = new Alerta
        {
            UsuarioId = parcela.UsuarioId,
            ParcelaId = parcela.Id,
            Fecha = DateTime.Today,
            EventoClimaticoId = eventoClimaticoId,
            NivelRiesgo = rule.NivelRiesgo,
            Accion1 = rule.Accion1,
            Accion2 = rule.Accion2,
            Accion3 = rule.Accion3,
            DescripcionAlerta = rule.DescripcionAlerta
        };
        alert.Id = await _alertaService.GuardarOActualizar(alert);
        return alert;
    }

    private static int DetermineActiveEvent(
        DatosClimaticos datoMasReciente,
        List<DatosClimaticos> historial,
        UmbralConfiguracion umbrales)
    {
        if (datoMasReciente.TemperaturaMin is not null && datoMasReciente.TemperaturaMin <= 2)
            return (int)EventoClimaticoId.RiesgoHelada;

        if (datoMasReciente.Precipitacion is not null && datoMasReciente.Precipitacion >= umbrales.LluviaIntensaMm)
            return (int)EventoClimaticoId.LluviaIntensa;

        if (datoMasReciente.VientoVelocidad is not null && datoMasReciente.VientoVelocidad >= umbrales.VientoFuerteKmh)
            return (int)EventoClimaticoId.VientoFuerte;

        if (datoMasReciente.TemperaturaMax is not null && datoMasReciente.TemperaturaMax >= 35)
            return (int)EventoClimaticoId.TemperaturaExtrema;

        if (HayCaniculaActiva(historial, umbrales.CaniculaDias))
            return (int)EventoClimaticoId.Canicula;

        return (int)EventoClimaticoId.SinRiesgo;
    }

    private static bool HayCaniculaActiva(List<DatosClimaticos> historial, int diasRequeridos)
    {
        if (historial.Count < diasRequeridos) return false;
        var ultimosNDias = historial.Take(diasRequeridos);
        return ultimosNDias.All(d => d.Precipitacion is null || d.Precipitacion == 0);
    }
}