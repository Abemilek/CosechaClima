using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Caching.Memory;
using Npgsql;
using NpgsqlTypes;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

namespace WebApi.Implementation;

public class ReglaDecisionService : IReglaDecisionService
{
    private const string CacheActivas = "reglas:activas";
    private const string CachePaquete = "reglas:paquete";

    // Tope de seguridad por si hay mas de una instancia de la API (la invalidacion
    // explicita solo alcanza a la instancia que recibio el cambio).
    private static readonly TimeSpan Vigencia = TimeSpan.FromMinutes(10);

    private const string ColumnasRegla =
        "id, evento_climatico_id, cultivo_id, etapa_fenologica_id, tipo_suelo_id, " +
        "nivel_riesgo, accion1, accion2, accion3, descripcion_alerta, activa";

    private readonly ConnectionBD _connectionBD;
    private readonly IMemoryCache _cache;
    private readonly ICatalogoService _catalogoService;

    public ReglaDecisionService(
        ConnectionBD connectionBD, IMemoryCache cache, ICatalogoService catalogoService)
    {
        _connectionBD = connectionBD;
        _cache = cache;
        _catalogoService = catalogoService;
    }

    public async Task<List<ReglaDecision>> ObtenerTodas()
    {
        var lista = new List<ReglaDecision>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasRegla} FROM reglas_decision ORDER BY id",
            connection);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
        {
            lista.Add(MapRegla(lector));
        }

        return lista;
    }

    public async Task<ReglaDecision?> ObtenerPorId(int id)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            $"SELECT {ColumnasRegla} FROM reglas_decision WHERE id = @Id", connection);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapRegla(lector) : null;
    }

    /// <summary>
    /// Busca la regla activa de la combinacion. Antes cada llamada abria una conexion y
    /// consultaba la base (el resumen semanal llegaba a hacer decenas); ahora las ~540 reglas
    /// activas viven en memoria y se invalidan cuando un admin las edita.
    /// </summary>
    public async Task<ReglaDecision?> ObtenerPorClave(
        int eventoClimaticoId, int cultivoId, int etapaFenologicaId, int tipoSueloId)
    {
        var activas = await ObtenerActivasEnCache();
        return activas.TryGetValue((eventoClimaticoId, cultivoId, etapaFenologicaId, tipoSueloId), out var regla)
            ? regla
            : null;
    }

    public async Task<bool> ActualizarContenido(
        int id, string nivelRiesgo, string accion1, string accion2, string accion3, string descripcionAlerta)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE reglas_decision SET nivel_riesgo = @NivelRiesgo, accion1 = @Accion1, " +
            "accion2 = @Accion2, accion3 = @Accion3, descripcion_alerta = @DescripcionAlerta " +
            "WHERE id = @Id", connection);

        command.Parameters.AddWithValue("@NivelRiesgo", nivelRiesgo);
        command.Parameters.AddWithValue("@Accion1", accion1);
        command.Parameters.AddWithValue("@Accion2", accion2);
        command.Parameters.AddWithValue("@Accion3", accion3);
        command.Parameters.AddWithValue("@DescripcionAlerta", descripcionAlerta);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var filas = await command.ExecuteNonQueryAsync();
        Invalidar();
        return filas > 0;
    }

    public async Task<bool> CambiarActiva(int id, bool activa)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            "UPDATE reglas_decision SET activa = @Activa WHERE id = @Id", connection);

        command.Parameters.AddWithValue("@Activa", activa);
        command.Parameters.AddWithValue("@Id", id);

        await connection.OpenAsync();
        var filas = await command.ExecuteNonQueryAsync();
        Invalidar();
        return filas > 0;
    }

    /// <summary>
    /// Crea la regla placeholder de cada combinacion que aun no existe.
    /// ON CONFLICT DO NOTHING (sobre la clave unica) reemplaza al NOT EXISTS: es atomico
    /// y seguro si dos instancias arrancan a la vez.
    /// </summary>
    public async Task SembrarReglasIniciales()
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new NpgsqlCommand(
            @"INSERT INTO reglas_decision (evento_climatico_id, cultivo_id, etapa_fenologica_id, tipo_suelo_id,
                nivel_riesgo, accion1, accion2, accion3, descripcion_alerta)
              SELECT ec.id, c.id, ef.id, ts.id,
                  CASE WHEN ec.nombre = 'Sin riesgo' THEN 'Bajo' ELSE 'PENDIENTE' END,
                  CASE WHEN ec.nombre = 'Sin riesgo' THEN 'Continuar con el manejo habitual del cultivo'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.nombre = 'Sin riesgo' THEN 'Revisar la parcela de forma rutinaria'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.nombre = 'Sin riesgo' THEN 'No se requiere accion inmediata'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.nombre = 'Sin riesgo'
                       THEN 'Condiciones normales para ' || c.nombre || ' en etapa ' || ef.nombre
                       ELSE 'Regla generada automaticamente para ' || ec.nombre || ' / ' || c.nombre
                            || ' / ' || ef.nombre || ' / ' || ts.nombre
                  END
              FROM eventos_climaticos ec
              CROSS JOIN cultivos c
              CROSS JOIN etapas_fenologicas ef
              CROSS JOIN tipos_suelo ts
              ON CONFLICT (evento_climatico_id, cultivo_id, etapa_fenologica_id, tipo_suelo_id) DO NOTHING",
            connection);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
        Invalidar();
    }

    public async Task AplicarContenidoPreliminar(bool soloPendientes = true)
    {
        var rutaArchivo = Path.Combine(AppContext.BaseDirectory, "Scripts", "reglas-preliminares-completas.json");
        var json = await File.ReadAllTextAsync(rutaArchivo);

        using var connection = _connectionBD.CrearConexion();

        // Antes este UPDATE corria en cada arranque y pisaba las ediciones del admin.
        // Con soloPendientes (por defecto) solo toca reglas que nadie curo todavia.
        var filtroPendientes = soloPendientes ? "AND rd.nivel_riesgo = 'PENDIENTE' " : string.Empty;

        using var command = new NpgsqlCommand(
            @"UPDATE reglas_decision rd
              SET nivel_riesgo = j.""nivelRiesgo"",
                  accion1 = j.accion1,
                  accion2 = j.accion2,
                  accion3 = j.accion3,
                  descripcion_alerta = j.descripcion
              FROM cultivos c, eventos_climaticos ec, etapas_fenologicas ef, tipos_suelo ts,
                   jsonb_to_recordset(@JsonReglas) AS j(
                       cultivo text, evento text, ""etapaFenologica"" text, ""tipoSuelo"" text,
                       ""nivelRiesgo"" text, accion1 text, accion2 text, accion3 text, descripcion text)
              WHERE c.id = rd.cultivo_id
                AND ec.id = rd.evento_climatico_id
                AND ef.id = rd.etapa_fenologica_id
                AND ts.id = rd.tipo_suelo_id
                AND c.nombre = j.cultivo
                AND ec.nombre = j.evento
                AND ef.nombre = j.""etapaFenologica""
                AND ts.nombre = j.""tipoSuelo"" " + filtroPendientes, connection);

        command.Parameters.Add(new NpgsqlParameter("@JsonReglas", NpgsqlDbType.Jsonb) { Value = json });

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
        Invalidar();
    }

    public async Task<PaqueteReglas> ObtenerPaquete()
    {
        if (_cache.TryGetValue(CachePaquete, out PaqueteReglas? enCache) && enCache is not null)
            return enCache;

        var activas = await ObtenerActivasEnCache();

        var reglas = activas.Values
            .OrderBy(r => r.EventoClimaticoId)
            .ThenBy(r => r.CultivoId)
            .ThenBy(r => r.TipoSueloId)
            .ThenBy(r => r.EtapaFenologicaId)
            .Select(r => new ReglaPaquete
            {
                EventoClimaticoId = r.EventoClimaticoId,
                CultivoId = r.CultivoId,
                EtapaFenologicaId = r.EtapaFenologicaId,
                TipoSueloId = r.TipoSueloId,
                NivelRiesgo = r.NivelRiesgo,
                Accion1 = r.Accion1,
                Accion2 = r.Accion2,
                Accion3 = r.Accion3,
                DescripcionAlerta = r.DescripcionAlerta
            })
            .ToList();

        var paquete = new PaqueteReglas
        {
            Version = CalcularVersion(reglas),
            GeneradoEn = DateTime.UtcNow,
            Eventos = await _catalogoService.ObtenerEventosClimaticos(),
            Cultivos = await _catalogoService.ObtenerCultivos(),
            TiposSuelo = await _catalogoService.ObtenerTiposSuelo(),
            Etapas = await _catalogoService.ObtenerEtapasFenologicas(),
            Reglas = reglas
        };

        _cache.Set(CachePaquete, paquete, Vigencia);
        return paquete;
    }

    /// <summary>
    /// Version = primeros 16 hex de SHA-256 sobre el contenido canonico de las reglas
    /// (ordenadas por evento, cultivo, suelo, etapa; campos separados por U+001F y reglas por salto de linea).
    /// La app embebida en el APK usa el mismo calculo (ver mobile/tool), asi que un servidor sin cambios
    /// devuelve 304 desde el primer arranque.
    /// </summary>
    public static string CalcularVersion(IEnumerable<ReglaPaquete> reglasOrdenadas)
    {
        var sb = new StringBuilder();
        var primera = true;
        foreach (var r in reglasOrdenadas)
        {
            if (!primera) sb.Append('\n');
            primera = false;
            sb.Append(r.EventoClimaticoId).Append('\u001f')
              .Append(r.CultivoId).Append('\u001f')
              .Append(r.TipoSueloId).Append('\u001f')
              .Append(r.EtapaFenologicaId).Append('\u001f')
              .Append(r.NivelRiesgo).Append('\u001f')
              .Append(r.Accion1).Append('\u001f')
              .Append(r.Accion2).Append('\u001f')
              .Append(r.Accion3).Append('\u001f')
              .Append(r.DescripcionAlerta);
        }

        var hash = SHA256.HashData(Encoding.UTF8.GetBytes(sb.ToString()));
        return Convert.ToHexString(hash).ToLowerInvariant()[..16];
    }

    private async Task<Dictionary<(int, int, int, int), ReglaDecision>> ObtenerActivasEnCache()
    {
        if (_cache.TryGetValue(CacheActivas, out Dictionary<(int, int, int, int), ReglaDecision>? enCache)
            && enCache is not null)
            return enCache;

        var todas = await ObtenerTodas();
        var activas = todas
            .Where(r => r.Activa)
            .ToDictionary(r => (r.EventoClimaticoId, r.CultivoId, r.EtapaFenologicaId, r.TipoSueloId));

        _cache.Set(CacheActivas, activas, Vigencia);
        return activas;
    }

    private void Invalidar()
    {
        _cache.Remove(CacheActivas);
        _cache.Remove(CachePaquete);
    }

    private static ReglaDecision MapRegla(NpgsqlDataReader lector)
    {
        return new ReglaDecision
        {
            Id = lector.GetInt32(0),
            EventoClimaticoId = lector.GetInt32(1),
            CultivoId = lector.GetInt32(2),
            EtapaFenologicaId = lector.GetInt32(3),
            TipoSueloId = lector.GetInt32(4),
            NivelRiesgo = lector.GetString(5),
            Accion1 = lector.GetString(6),
            Accion2 = lector.GetString(7),
            Accion3 = lector.GetString(8),
            DescripcionAlerta = lector.GetString(9),
            Activa = lector.GetBoolean(10)
        };
    }
}
