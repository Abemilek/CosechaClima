namespace WebApi.Models;

public static class MunicipioCentroide {
    public readonly record struct Centroide(decimal Latitud, decimal Longitud);

    private static readonly Dictionary<string, Centroide> _centroides = new(StringComparer.OrdinalIgnoreCase) {
        ["Diriamba"] = new Centroide(11.850m, -86.233m),
        ["Jinotepe"] = new Centroide(11.850m, -86.200m),
        ["San Marcos"] = new Centroide(11.917m, -86.200m),
        ["Dolores"] = new Centroide(11.850m, -86.217m),
    };

    public static bool TryObtenerCentroide(string? municipio, out Centroide centroide) {
        centroide = default;
        if (string.IsNullOrWhiteSpace(municipio)) return false;
        return _centroides.TryGetValue(municipio.Trim(), out centroide);
    }
}
