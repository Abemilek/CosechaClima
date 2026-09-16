using WebApi.Interface;
using WebApi.Models;
using WebApi.Implementation.Exceptions;
using System.Collections.Generic;
using System.Linq;

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
            ?? throw new RecursoNoEncontradoException($"no existe la parcela {parcelaId}");

        var etapaFenologicaId = parcela.EtapaFenologicaId
            ?? (await _etapaFenologicaService.CalcularDesdeFecha(parcela.FechaSiembra)).Id;

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? throw new FlujoIncompletoException("el usuario no tiene umbrales configurados");

        var ultimoDato = (await _datosClimaticoService.ObtenerUltimosDatos(parcelaId, dias: 1))
            .FirstOrDefault();

        if (ultimoDato is null)
            throw new FlujoIncompletoException("no hay datos climaticos disponibles para esta parcela");

        var diasNecesarios = Math.Max(umbrales.CaniculaDias, 1);
        var fechaDesde = DateTime.Today.AddDays(-(diasNecesarios - 1));
        var ventanaCanicula = await _datosClimaticoService.ObtenerPorRangoFechas(
            parcelaId, fechaDesde, DateTime.Today);

        var eventosActivos = DetermineActiveEvents(ultimoDato, ventanaCanicula, umbrales, diasNecesarios);

        ReglaDecision? reglaPrioritaria = null;
        int maxPrioridad = -1;

        foreach (var eventoId in eventosActivos)
        {
            var rule = await _reglaDecisionService.ObtenerPorClave(
                eventoId, parcela.CultivoId, etapaFenologicaId, parcela.TipoSueloId);

            if (rule != null)
            {
                int prioridad = CalcularPrioridadRiesgo(rule.NivelRiesgo);
                if (prioridad > maxPrioridad)
                {
                    maxPrioridad = prioridad;
                    reglaPrioritaria = rule;
                }
            }
        }

        if (reglaPrioritaria is null)
            throw new FlujoIncompletoException(
                "no existe una regla agronomica para esta combinacion de cultivo, etapa y suelo");

        var alert = new Alerta
        {
            UsuarioId = parcela.UsuarioId,
            ParcelaId = parcela.Id,
            Fecha = DateTime.Today,
            EventoClimaticoId = reglaPrioritaria.EventoClimaticoId,
            NivelRiesgo = reglaPrioritaria.NivelRiesgo,
            Accion1 = reglaPrioritaria.Accion1,
            Accion2 = reglaPrioritaria.Accion2,
            Accion3 = reglaPrioritaria.Accion3,
            DescripcionAlerta = reglaPrioritaria.DescripcionAlerta
        };
        
        alert.Id = await _alertaService.GuardarOActualizar(alert);
        return alert;
    }

    private static List<int> DetermineActiveEvents(
        DatosClimaticos ultimoDato,
        List<DatosClimaticos> ventanaCanicula,
        UmbralConfiguracion umbrales,
        int diasNecesarios)
    {
        var eventos = new List<int>();

        if (ultimoDato.TemperaturaMin is not null && ultimoDato.TemperaturaMin <= 2m)
            eventos.Add((int)EventoClimaticoId.RiesgoHelada);

        if (ultimoDato.Precipitacion is not null && ultimoDato.Precipitacion >= umbrales.LluviaIntensaMm)
            eventos.Add((int)EventoClimaticoId.LluviaIntensa);

        if (ultimoDato.VientoVelocidad is not null && ultimoDato.VientoVelocidad >= umbrales.VientoFuerteKmh)
            eventos.Add((int)EventoClimaticoId.VientoFuerte);

        if (ultimoDato.TemperaturaMax is not null && ultimoDato.TemperaturaMax >= 35m)
            eventos.Add((int)EventoClimaticoId.TemperaturaExtrema);

        if (HayCaniculaActiva(ventanaCanicula, diasNecesarios, DateTime.Today))
            eventos.Add((int)EventoClimaticoId.Canicula);

        if (!eventos.Any())
            eventos.Add((int)EventoClimaticoId.SinRiesgo);

        return eventos;
    }

    private static int CalcularPrioridadRiesgo(string nivel) => nivel.ToLower() switch
    {
        "alto" => 3,
        "medio" => 2,
        "bajo" => 1,
        _ => 0
    };

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