using System.Linq;

namespace WebApi.Models;

public static class MunicipioCentroide {
    public readonly record struct Centroide(decimal Latitud, decimal Longitud);

    private static readonly Dictionary<string, Centroide> _centroidesCarazo = new(StringComparer.OrdinalIgnoreCase) {
        ["Diriamba"] = new Centroide(11.850m, -86.233m),
        ["Jinotepe"] = new Centroide(11.850m, -86.200m),
        ["San Marcos"] = new Centroide(11.917m, -86.200m),
        ["Dolores"] = new Centroide(11.850m, -86.217m),
        ["El Rosario"] = new Centroide(11.833m, -86.167m),
        ["La Conquista"] = new Centroide(11.733m, -86.200m),
        ["La Paz de Carazo"] = new Centroide(11.817m, -86.133m),
        ["Santa Teresa"] = new Centroide(11.733m, -86.217m),
    };

    private static readonly Dictionary<string, Centroide> _centroidesDepartamento = new(StringComparer.OrdinalIgnoreCase) {
        ["Boaco"] = new Centroide(12.472m, -85.662m),
        ["Carazo"] = new Centroide(11.850m, -86.200m),
        ["Chinandega"] = new Centroide(12.630m, -87.130m),
        ["Chontales"] = new Centroide(12.097m, -85.367m),
        ["Estelí"] = new Centroide(13.091m, -86.354m),
        ["Granada"] = new Centroide(11.930m, -85.956m),
        ["Jinotega"] = new Centroide(13.092m, -85.999m),
        ["León"] = new Centroide(12.434m, -86.878m),
        ["Madriz"] = new Centroide(13.469m, -86.587m),
        ["Managua"] = new Centroide(12.136m, -86.251m),
        ["Masaya"] = new Centroide(11.974m, -86.094m),
        ["Matagalpa"] = new Centroide(12.925m, -85.918m),
        ["Nueva Segovia"] = new Centroide(13.633m, -86.483m),
        ["Rivas"] = new Centroide(11.439m, -85.828m),
        ["Río San Juan"] = new Centroide(11.123m, -84.776m),
        ["Región Autónoma de la Costa Caribe Norte"] = new Centroide(14.033m, -83.383m),
        ["Región Autónoma de la Costa Caribe Sur"] = new Centroide(11.994m, -83.756m),
    };

    private static readonly Dictionary<string, Centroide> _centroides =
        _centroidesCarazo
            .Concat(_centroidesDepartamento)
            .GroupBy(kv => kv.Key, StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.First().Value, StringComparer.OrdinalIgnoreCase);

    public static readonly IReadOnlyList<string> MunicipiosCarazo = _centroidesCarazo.Keys.ToList();

    public static readonly IReadOnlyList<string> Departamentos = _centroidesDepartamento.Keys.ToList();

    public static bool TryObtenerCentroide(string? municipio, out Centroide centroide) {
        centroide = default;
        if (string.IsNullOrWhiteSpace(municipio)) return false;
        return _centroides.TryGetValue(municipio.Trim(), out centroide);
    }
}
