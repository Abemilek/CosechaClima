namespace WebApi.Models;

public static class ZonaCobertura {
    public const decimal LatitudMinima = 11.55m;
    public const decimal LatitudMaxima = 11.95m;
    public const decimal LongitudMinima = -86.45m;
    public const decimal LongitudMaxima = -86.05m;

    public static bool EstaDentroDeCarazo(decimal? latitud, decimal? longitud) {
        if (latitud is null || longitud is null) return false;

        return latitud >= LatitudMinima && latitud <= LatitudMaxima
            && longitud >= LongitudMinima && longitud <= LongitudMaxima;
    }
}
