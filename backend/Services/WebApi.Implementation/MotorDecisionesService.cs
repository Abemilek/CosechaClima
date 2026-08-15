using Microsoft.Data.SqlClient;
using WebApi.Interface;
using WebApi.Implementation.Connection;
using WebApi.Models;

namespace WebApi.Implementation;

public class MotorDecisionesService : IMotorDecisionesService
{
    private readonly IParcelaService _parcelaService;
    private readonly IUmbralConfiguracionService _umbralService;
    private readonly IDatosClimaticoService _datosClimaticoService;
    private readonly IReglaDecisionService _reglaDecisionService;
    private readonly IAlertaService _alertaService;

    public MotorDecisionesService(
        IParcelaService parcelaService,
        IUmbralConfiguracionService umbralService,
        IDatosClimaticoService datosClimaticoService,
        IReglaDecisionService reglaDecisionService,
        IAlertaService alertaService)
    {
        _parcelaService = parcelaService;
        _umbralService = umbralService;
        _datosClimaticoService = datosClimaticoService;
        _reglaDecisionService = reglaDecisionService;
        _alertaService = alertaService;
    }

    public async Task<Alerta> CalcularSemaforo(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId)
            ?? throw new InvalidOperationException($"No existe la parcela {parcelaId}");

        if (parcela.EtapaFenologicaId is null)
            throw new InvalidOperationException("La parcela no tiene etapa fenologica asignada");

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? throw new InvalidOperationException("El usuario no tiene umbrales configurados");

        // dato mas reciente para los umbrales de un solo dia
        var ultimoDato = (await _datosClimaticoService.ObtenerUltimosDatos(parcelaId, dias: 1))
            .FirstOrDefault();

        if (ultimoDato is null)
            throw new InvalidOperationException("No hay datos climaticos disponibles para esta parcela");

        var diasNecesarios = Math.Max(umbrales.CaniculaDias, 1);
        var fechaDesde = DateTime.Today.AddDays(-(diasNecesarios - 1));
        var ventanaCanicula = await _datosClimaticoService.ObtenerPorRangoFechas(
            parcelaId, fechaDesde, DateTime.Today);

        var eventoClimaticoId = DetermineActiveEvent(ultimoDato, ventanaCanicula, umbrales, diasNecesarios);

        var rules = await _reglaDecisionService.ObtenerTodas();
        var rule = rules.FirstOrDefault(r =>
            r.EventoClimaticoId == eventoClimaticoId &&
            r.CultivoId == parcela.CultivoId &&
            r.EtapaFenologicaId == parcela.EtapaFenologicaId &&
            r.TipoSueloId == parcela.TipoSueloId);

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
        DatosClimaticos ultimoDato,
        List<DatosClimaticos> ventanaCanicula,
        UmbralConfiguracion umbrales,
        int diasNecesarios)
    {
        if (ultimoDato.TemperaturaMin is not null && ultimoDato.TemperaturaMin <= 2)
            return (int)EventoClimaticoId.RiesgoHelada;

        if (ultimoDato.Precipitacion is not null && ultimoDato.Precipitacion >= umbrales.LluviaIntensaMm)
            return (int)EventoClimaticoId.LluviaIntensa;

        if (ultimoDato.VientoVelocidad is not null && ultimoDato.VientoVelocidad >= umbrales.VientoFuerteKmh)
            return (int)EventoClimaticoId.VientoFuerte;

        if (ultimoDato.TemperaturaMax is not null && ultimoDato.TemperaturaMax >= 35)
            return (int)EventoClimaticoId.TemperaturaExtrema;

        // sin huecos de conectividad
        if (HayCaniculaActiva(ventanaCanicula, diasNecesarios, DateTime.Today))
            return (int)EventoClimaticoId.Canicula;

        return (int)EventoClimaticoId.SinRiesgo;
    }

    private static bool HayCaniculaActiva(List<DatosClimaticos> historial, int diasRequeridos, DateTime fechaReferencia)
    {
        var fechasEsperadas = Enumerable.Range(0, diasRequeridos)
            .Select(offset => fechaReferencia.AddDays(-offset).Date)
            .ToHashSet();

        var fechasDisponibles = historial.Select(d => d.Fecha.Date).ToHashSet();

        if (!fechasEsperadas.IsSubsetOf(fechasDisponibles))
            return false;

        return historial
            .Where(d => fechasEsperadas.Contains(d.Fecha.Date))
            .All(d => d.Precipitacion is null || d.Precipitacion == 0);
    }
}