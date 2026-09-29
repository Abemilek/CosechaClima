namespace WebApi.Models;

public static class ZonaCobertura {
    public const decimal LatitudMinima = 10.70m;
    public const decimal LatitudMaxima = 15.03m;
    public const decimal LongitudMinima = -87.70m;
    public const decimal LongitudMaxima = -82.70m;

    public static bool EstaDentroDeNicaragua(decimal? latitud, decimal? longitud) {
        if (latitud is null || longitud is null) return false;

        return latitud >= LatitudMinima && latitud <= LatitudMaxima
            && longitud >= LongitudMinima && longitud <= LongitudMaxima;
    }

    public static bool EstaDentroDeCarazo(decimal? latitud, decimal? longitud) =>
        EstaDentroDeNicaragua(latitud, longitud);
}
