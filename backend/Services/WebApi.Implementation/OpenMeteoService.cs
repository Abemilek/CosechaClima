using System.Net.Http.Json;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class OpenMeteoService : IProveedorClimaticoService
{
    private readonly HttpClient _httpClient;
    private readonly IDatosClimaticoService _datosClimaticoService;

    public OpenMeteoService(HttpClient httpClient, IDatosClimaticoService datosClimaticoService)
    {
        _httpClient = httpClient;
        _datosClimaticoService = datosClimaticoService;
    }

    public async Task<DatosClimaticos?> ObtenerYGuardarDatosActuales(int parcelaId, decimal latitud, decimal longitud)
    {
        var url = $"?latitude={latitud}&longitude={longitud}" +
                   "&daily=temperature_2m_max,temperature_2m_min,precipitation_sum,windspeed_10m_max" +
                   "&timezone=America%2FManagua&past_days=1&forecast_days=3";

        try
        {
            var respuesta = await _httpClient.GetFromJsonAsync<OpenMeteoRespuesta>(url);
            var diario = respuesta?.Daily;

            if (diario?.Time is null || diario.Time.Count == 0)
                return await UsarUltimoDatoGuardado(parcelaId);

            var indiceHoy = diario.Time.Count > 1 ? 1 : 0;
            var indicesAGuardar = diario.Time.Count > 1
                ? new[] { 0, 1 }
                : new[] { 0 };

            DatosClimaticos? datoDeHoy = null;

            foreach (var indice in indicesAGuardar)
            {
                var fecha = DateTime.Parse(diario.Time[indice]);

                var dato = new DatosClimaticos
                {
                    ParcelaId = parcelaId,
                    Fecha = fecha.Date,
                    TemperaturaMax = ObtenerValor(diario.Temperature2mMax, indice),
                    TemperaturaMin = ObtenerValor(diario.Temperature2mMin, indice),
                    Precipitacion = ObtenerValor(diario.PrecipitationSum, indice),
                    VientoVelocidad = ObtenerValor(diario.Windspeed10mMax, indice),
                    FuenteClima = "OPEN_METEO"
                };

                await _datosClimaticoService.GuardarOActualizar(dato);

                if (indice == indiceHoy)
                    datoDeHoy = dato;
            }

            return datoDeHoy;
        }
        catch (HttpRequestException)
        {
            return await UsarUltimoDatoGuardado(parcelaId);
        }
        catch (TaskCanceledException)
        {
            return await UsarUltimoDatoGuardado(parcelaId);
        }
    }

    private async Task<DatosClimaticos?> UsarUltimoDatoGuardado(int parcelaId)
    {
        var ultimos = await _datosClimaticoService.ObtenerUltimosDatos(parcelaId, dias: 1);
        return ultimos.FirstOrDefault();
    }

    private static decimal? ObtenerValor(List<decimal?>? lista, int indice)
    {
        if (lista is null || indice >= lista.Count)
            return null;

        return lista[indice];
    }

    // deserializar el json de open meteo
    internal class OpenMeteoRespuesta
    {
        public OpenMeteoDaily? Daily { get; set; }
    }

    internal class OpenMeteoDaily
    {
        public List<string>? Time { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("temperature_2m_max")]
        public List<decimal?>? Temperature2mMax { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("temperature_2m_min")]
        public List<decimal?>? Temperature2mMin { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("precipitation_sum")]
        public List<decimal?>? PrecipitationSum { get; set; }

        [System.Text.Json.Serialization.JsonPropertyName("windspeed_10m_max")]
        public List<decimal?>? Windspeed10mMax { get; set; }
    }
}