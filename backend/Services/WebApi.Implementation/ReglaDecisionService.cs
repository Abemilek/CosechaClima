using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;
using System.Text.Json;
using System.Data;

namespace WebApi.Implementation;

public class ReglaDecisionService : IReglaDecisionService
{
    private readonly ConnectionBD _connectionBD;

    public ReglaDecisionService(ConnectionBD connectionBD)
    {
        _connectionBD = connectionBD;
    }

    public async Task<List<ReglaDecision>> ObtenerTodas()
    {
        var lista = new List<ReglaDecision>();

        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId, " +
            "NivelRiesgo, Accion1, Accion2, Accion3, DescripcionAlerta FROM ReglasDecision",
            connection);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        while (await lector.ReadAsync())
        {
            lista.Add(MapRegla(lector));
        }

        return lista;
    }

    public async Task<ReglaDecision?> ObtenerPorClave(
        int eventoClimaticoId, int cultivoId, int etapaFenologicaId, int tipoSueloId)
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            "SELECT Id, EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId, " +
            "NivelRiesgo, Accion1, Accion2, Accion3, DescripcionAlerta FROM ReglasDecision " +
            "WHERE EventoClimaticoId = @Evento AND CultivoId = @Cultivo " +
            "AND EtapaFenologicaId = @Etapa AND TipoSueloId = @Suelo", connection);

        command.Parameters.AddWithValue("@Evento", eventoClimaticoId);
        command.Parameters.AddWithValue("@Cultivo", cultivoId);
        command.Parameters.AddWithValue("@Etapa", etapaFenologicaId);
        command.Parameters.AddWithValue("@Suelo", tipoSueloId);

        await connection.OpenAsync();
        using var lector = await command.ExecuteReaderAsync();

        return await lector.ReadAsync() ? MapRegla(lector) : null;
    }

    public async Task SembrarReglasIniciales()
    {
        using var connection = _connectionBD.CrearConexion();
        using var command = new SqlCommand(
            @"INSERT INTO ReglasDecision (EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId,
                NivelRiesgo, Accion1, Accion2, Accion3, DescripcionAlerta)
              SELECT ec.Id, c.Id, ef.Id, ts.Id,
                  CASE WHEN ec.Nombre = 'Sin riesgo' THEN 'Bajo' ELSE 'PENDIENTE' END,
                  CASE WHEN ec.Nombre = 'Sin riesgo' THEN 'Continuar con el manejo habitual del cultivo'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.Nombre = 'Sin riesgo' THEN 'Revisar la parcela de forma rutinaria'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.Nombre = 'Sin riesgo' THEN 'No se requiere accion inmediata'
                       ELSE 'PENDIENTE - definir con tecnico INTA' END,
                  CASE WHEN ec.Nombre = 'Sin riesgo'
                       THEN CONCAT('Condiciones normales para ', c.Nombre, ' en etapa ', ef.Nombre)
                       ELSE CONCAT('Regla generada automaticamente para ', ec.Nombre, ' / ', c.Nombre, ' / ', ef.Nombre, ' / ', ts.Nombre)
                  END
              FROM EventoClimatico ec
              CROSS JOIN Cultivos c
              CROSS JOIN EtapaFenologica ef
              CROSS JOIN TipoSuelo ts
              WHERE NOT EXISTS (
                  SELECT 1 FROM ReglasDecision rd
                  WHERE rd.EventoClimaticoId = ec.Id AND rd.CultivoId = c.Id
                    AND rd.EtapaFenologicaId = ef.Id AND rd.TipoSueloId = ts.Id
              )", connection);

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    public async Task AplicarContenidoPreliminar()
    {
        var rutaArchivo = Path.Combine(AppContext.BaseDirectory, "Scripts", "reglas-preliminares-completas.json");
        var json = await File.ReadAllTextAsync(rutaArchivo);

        using var connection = _connectionBD.CrearConexion();
        
        using var command = new SqlCommand(
            @"UPDATE rd
              SET NivelRiesgo = j.NivelRiesgo, 
                  Accion1 = j.Accion1, 
                  Accion2 = j.Accion2,
                  Accion3 = j.Accion3, 
                  DescripcionAlerta = j.Descripcion
              FROM ReglasDecision rd
              JOIN Cultivos c ON c.Id = rd.CultivoId
              JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
              JOIN EtapaFenologica ef ON ef.Id = rd.EtapaFenologicaId
              JOIN TipoSuelo ts ON ts.Id = rd.TipoSueloId
              JOIN OPENJSON(@JsonReglas) WITH (
                  Cultivo NVARCHAR(100),
                  Evento NVARCHAR(100),
                  EtapaFenologica NVARCHAR(100) '$.EtapaFenologica',
                  TipoSuelo NVARCHAR(100),
                  NivelRiesgo NVARCHAR(50),
                  Accion1 NVARCHAR(500),
                  Accion2 NVARCHAR(500),
                  Accion3 NVARCHAR(500),
                  Descripcion NVARCHAR(500)
              ) j ON c.Nombre = j.Cultivo 
                 AND ec.Nombre = j.Evento 
                 AND ef.Nombre = j.EtapaFenologica 
                 AND ts.Nombre = j.TipoSuelo;", connection);

        var jsonParam = command.Parameters.Add("@JsonReglas", SqlDbType.NVarChar, -1);
        jsonParam.Value = json;

        await connection.OpenAsync();
        await command.ExecuteNonQueryAsync();
    }

    private static ReglaDecision MapRegla(SqlDataReader lector)
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
            DescripcionAlerta = lector.GetString(9)
        };
    }
}