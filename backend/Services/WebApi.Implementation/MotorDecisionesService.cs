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

    public async Task<Alerta> CalcularSemaforo (int parcelaId) // i dont know what i am doing lol
    {
        var parcela = await _parcelaService.ObtenerPorId(parcelaId)
            ?? throw new InvalidOperationException($"No existe la parcela {parcelaId}");

        if (parcela.EtapaFenologicaId is null)
            throw new InvalidOperationException("La parcela no tiene etapa fenologica asignada");

        var umbrales = await _umbralService.ObtenerPorUsuario(parcela.UsuarioId)
            ?? throw new InvalidOperationException("El usuario no tiene umbrales configurados");

        var lastData = await _datosClimaticoService.ObtenerUltimosDatos(parcelaId, dias: 1);
        var todayData = lastData.FirstOrDefault()
            ?? throw new InvalidOperationException("No hay datos climaticos disponibles para esta parcela"); 

        int eventoClimaticoId = DetermineActiveEvent(todayData, umbrales);

        var rules = await _reglaDecisionService.ObtenerTodas();
        var rule = rules.FirstOrDefault(r =>
        r.EventoClimaticoId == eventoClimaticoId &&
        r.CultivoId == parcela.CultivoId &&
        r.EtapaFenologicaId == parcela.EtapaFenologicaId &&
        r.TipoSueloId == parcela.TipoSueloId);

        if (rule is null)
            throw new InvalidOperationException(
                $"No existe una regla para eventos={eventoClimaticoId}, Cultivo={parcela.CultivoId}, " +
                $"Etapa={parcela.EtapaFenologicaId}, Suelo={parcela.TipoSueloId}, Revisar seed de reglas decision");

        var alert = new Alerta
        {
            UsuarioId = parcela.UsuarioId,
            ParcelaId = parcela.Id,
            Fecha = DateTime.Today,
            EventoClimaticoId = eventoClimaticoId,
            NivelRiesgo = rule.NivelRiesgo,
            Accion1 = rule.Accion1,
            Accion2 =   rule.Accion2,
            Accion3 = rule.Accion3,
            DescripcionAlerta = rule.DescripcionAlerta
        };
        alert.Id = await _alertaService.GuardarOActualizar(alert);
        return alert;

    }

    private static int DetermineActiveEvent(DatosClimaticos dato, UmbralConfiguracion umbrales)
    {
        if (dato.TemperaturaMin is not null && dato.TemperaturaMin <= 2)
            return 5;

        if (dato.Precipitacion is not null && dato.Precipitacion >= umbrales.LluviaIntensaMm)
            return 1; // lluva intensa

        if (dato.VientoVelocidad is not null && dato.VientoVelocidad >= umbrales.VientoFuerteKmh)
            return 3; //viento fuerte

        if (dato.TemperaturaMax is not null && dato.TemperaturaMax >= 35)
            return 4; // temperatura extrema

        // por ahora se marca canicula si la precipitacion es 0
        if (dato.Precipitacion is not null && dato.Precipitacion == 0)
            return 2;

        throw new InvalidOperationException("Ningun evento climatico supera los umbrales configurados");
    }
}   