using System.Net.Http.Json;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class NasaPowerService : INasaPowerService
{
    private readonly HttpClient _httpClient;
    private readonly IDatosClimaticoService _datosClimaticoService;

    public NasaPowerService(HttpClient httpClient, IDatosClimaticoService datosClimaticoService)
    {
        _httpClient = httpClient;
        _datosClimaticoService = datosClimaticoService;
    }

    public async Task<DatosClimaticos?> ObtenerYGuardarDatosActuales(int parcelaId, decimal latitud, decimal longitud)
    {
        var hoy = DateTime.UtcNow.ToString("yyyyMMdd");
        var parametros = "T2M_MAX,T2M_MIN,PRECTOTCORR,WS10M";
        var url = $"?parameters={parametros}&community=AG&longitude={longitud}&latitude={latitud}" +
                  $"&start={hoy}&end={hoy}&format=JSON";

        try
        {
            var respuesta = await _httpClient.GetFromJsonAsync<NasaPowerRespuesta>(url);
            var datosDia = respuesta?.Properties?.Parameter;

            if (datosDia is null)
                return await UsarUltimoDatoGuardado(parcelaId);

            var claveDia = datosDia.T2M_MAX?.Keys.FirstOrDefault();
            if (claveDia is null)
                return await UsarUltimoDatoGuardado(parcelaId);

            var dato = new DatosClimaticos
            {
                ParcelaId = parcelaId,
                Fecha = DateTime.Today,
                TemperaturaMax = datosDia.T2M_MAX?[claveDia],
                TemperaturaMin = datosDia.T2M_MIN?[claveDia],
                Precipitacion = datosDia.PRECTOTCORR?[claveDia],
                VientoVelocidad = datosDia.WS10M?[claveDia],
                FuenteNASA = "POWER"
            };

            await _datosClimaticoService.GuardarDatos(dato);
            return dato;
        }
        catch (HttpRequestException)
        {
            // si no hay internet aqui se usa el ultimo dato guardado
            return await UsarUltimoDatoGuardado(parcelaId);
        }
        catch (TaskCanceledException)
        {
            return await UsarUltimoDatoGuardado(parcelaId);
        }
    }

    private async Task<DatosClimaticos?> UsarUltimoDatoGuardado(int parcelaId)
    {
        var ultimos = await _datosClimaticoService.ObtenerUltimosDatos(parcelaId, dias: 3);
        return ultimos.FirstOrDefault();
    }
}

// Clases auxiliares
internal class NasaPowerRespuesta
{
    public NasaPowerProperties? Properties { get; set; }
}

internal class NasaPowerProperties
{
    public NasaPowerParametros? Parameter { get; set; }
}

internal class NasaPowerParametros
{
    public Dictionary<string, decimal>? T2M_MAX { get; set; }
    public Dictionary<string, decimal>? T2M_MIN { get; set; }
    public Dictionary<string, decimal>? PRECTOTCORR { get; set; }
    public Dictionary<string, decimal>? WS10M { get; set; }
}