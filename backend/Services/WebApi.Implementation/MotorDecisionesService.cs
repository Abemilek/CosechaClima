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
    private readonly IProveedorClimaticoService _proveedorClimaticoService;

    public MotorDecisionesService(
        IParcelaService parcelaService,
        IUmbralConfiguracionService umbralService,
        IDatosClimaticoService datosClimaticoService,
        IReglaDecisionService reglaDecisionService,
        IAlertaService alertaService,
        IEtapaFenologicaService etapaFenologicaService,
        IProveedorClimaticoService proveedorClimaticoService)
    {
        _parcelaService = parcelaService;
        _umbralService = umbralService;
        _datosClimaticoService = datosClimaticoService;
        _reglaDecisionService = reglaDecisionService;
        _alertaService = alertaService;
        _etapaFenologicaService = etapaFenologicaService;
        _proveedorClimaticoService = proveedorClimaticoService;
    }

    public async Task<Alerta> CalcularSemaforo(int parcelaId)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId)
            ?? throw new RecursoNoEncontradoException($"no existe la parcela {parcelaId}");

        var etapaFenologicaId = parcela.EtapaFenologicaId
            ?? (await _etapaFenologicaService.CalcularDesdeFecha(parcela.FechaSiembra)).Id;

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? new UmbralConfiguracion { UsuarioId = parcela.UsuarioId };

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
        return DeterminarEventosActivos(
            ultimoDato.TemperaturaMin, ultimoDato.TemperaturaMax,
            ultimoDato.Precipitacion, ultimoDato.VientoVelocidad,
            umbrales,
            HayCaniculaActiva(ventanaCanicula, diasNecesarios, DateTime.Today));
    }

    private static List<int> DeterminarEventosActivos(
        decimal? temperaturaMin, decimal? temperaturaMax,
        decimal? precipitacion, decimal? viento,
        UmbralConfiguracion umbrales, bool caniculaActiva)
    {
        var eventos = new List<int>();

        if (temperaturaMin is not null && temperaturaMin <= 2m)
            eventos.Add((int)EventoClimaticoId.RiesgoHelada);

        if (precipitacion is not null && precipitacion >= umbrales.LluviaIntensaMm)
            eventos.Add((int)EventoClimaticoId.LluviaIntensa);

        if (viento is not null && viento >= umbrales.VientoFuerteKmh)
            eventos.Add((int)EventoClimaticoId.VientoFuerte);

        if (temperaturaMax is not null && temperaturaMax >= 35m)
            eventos.Add((int)EventoClimaticoId.TemperaturaExtrema);

        if (caniculaActiva)
            eventos.Add((int)EventoClimaticoId.Canicula);

        if (!eventos.Any())
            eventos.Add((int)EventoClimaticoId.SinRiesgo);

        return eventos;
    }

    public async Task<ResumenSemanal> CalcularResumenSemanal(int parcelaId, int dias = 7)
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId)
            ?? throw new RecursoNoEncontradoException($"no existe la parcela {parcelaId}");

        decimal latitud;
        decimal longitud;

        if (parcela.Latitud is not null && parcela.Longitud is not null)
        {
            latitud = parcela.Latitud.Value;
            longitud = parcela.Longitud.Value;
        }
        else if (MunicipioCentroide.TryObtenerCentroide(parcela.Municipio, out var centroide))
        {
            latitud = centroide.Latitud;
            longitud = centroide.Longitud;
        }
        else
        {
            throw new FlujoIncompletoException(
                "la parcela no tiene coordenadas GPS ni un municipio/departamento reconocido");
        }

        var etapaFenologicaId = parcela.EtapaFenologicaId
            ?? (await _etapaFenologicaService.CalcularDesdeFecha(parcela.FechaSiembra)).Id;

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? new UmbralConfiguracion { UsuarioId = parcela.UsuarioId };

        return await EvaluarResumenSemanal(
            parcela.CultivoId, etapaFenologicaId, parcela.TipoSueloId,
            latitud, longitud, umbrales, dias);
    }

    public async Task<ResumenSemanal> CalcularResumenSemanalAnonimo(
        int cultivoId, int? etapaFenologicaId, int tipoSueloId,
        decimal latitud, decimal longitud, DateTime fechaSiembra, int dias = 7)
    {
        var umbrales = new UmbralConfiguracion();

        var etapaId = etapaFenologicaId
            ?? (await _etapaFenologicaService.CalcularDesdeFecha(fechaSiembra)).Id;

        return await EvaluarResumenSemanal(
            cultivoId, etapaId, tipoSueloId, latitud, longitud, umbrales, dias);
    }

    private async Task<ResumenSemanal> EvaluarResumenSemanal(
        int cultivoId, int etapaFenologicaId, int tipoSueloId,
        decimal latitud, decimal longitud, UmbralConfiguracion umbrales, int dias)
    {
        var pronostico = await _proveedorClimaticoService.ObtenerPronosticoDiario(latitud, longitud, dias);

        var resumen = new ResumenSemanal();
        var diasNecesariosCanicula = Math.Max(umbrales.CaniculaDias, 1);

        ReglaDecision? reglaDelPeorDia = null;
        int prioridadMaxima = -1;

        for (var i = 0; i < pronostico.Count; i++)
        {
            var dia = pronostico[i];

            var ventana = pronostico
                .Where(d => d.Fecha <= dia.Fecha && d.Fecha > dia.Fecha.AddDays(-diasNecesariosCanicula))
                .ToList();
            var caniculaActiva = ventana.Count == diasNecesariosCanicula
                && ventana.All(d => d.Precipitacion is null || d.Precipitacion == 0);

            var eventosActivos = DeterminarEventosActivos(
                dia.TemperaturaMin, dia.TemperaturaMax, dia.Precipitacion, dia.VientoVelocidad,
                umbrales, caniculaActiva);

            ReglaDecision? reglaDelDia = null;
            int prioridadDelDia = -1;

            foreach (var eventoId in eventosActivos)
            {
                var regla = await _reglaDecisionService.ObtenerPorClave(
                    eventoId, cultivoId, etapaFenologicaId, tipoSueloId);

                if (regla is null) continue;

                var prioridad = CalcularPrioridadRiesgo(regla.NivelRiesgo);
                if (prioridad > prioridadDelDia)
                {
                    prioridadDelDia = prioridad;
                    reglaDelDia = regla;
                }
            }

            resumen.Dias.Add(new DiaResumenSemanal
            {
                Fecha = dia.Fecha,
                NivelRiesgo = reglaDelDia?.NivelRiesgo ?? "Bajo",
                EventoClimaticoId = reglaDelDia?.EventoClimaticoId ?? (int)EventoClimaticoId.SinRiesgo,
                TemperaturaMax = dia.TemperaturaMax,
                TemperaturaMin = dia.TemperaturaMin,
                Precipitacion = dia.Precipitacion,
            });

            if (reglaDelDia is not null && prioridadDelDia > prioridadMaxima)
            {
                prioridadMaxima = prioridadDelDia;
                reglaDelPeorDia = reglaDelDia;
                resumen.DiaMasCritico = dia.Fecha;
            }
        }

        if (reglaDelPeorDia is not null)
        {
            resumen.NivelRiesgoMaximo = reglaDelPeorDia.NivelRiesgo;
            resumen.DescripcionAlerta = reglaDelPeorDia.DescripcionAlerta;
            resumen.AccionesDeLaSemana = new List<string>
            {
                reglaDelPeorDia.Accion1, reglaDelPeorDia.Accion2, reglaDelPeorDia.Accion3
            };
        }
        else
        {
            resumen.NivelRiesgoMaximo = "Bajo";
            resumen.DescripcionAlerta = "Semana sin riesgos climáticos relevantes previstos.";
            resumen.AccionesDeLaSemana = new List<string> { "Continuar con el manejo habitual del cultivo" };
        }

        return resumen;
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