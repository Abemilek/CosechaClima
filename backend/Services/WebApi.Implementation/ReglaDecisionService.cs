using Microsoft.Data.SqlClient;
using WebApi.Implementation.Connection;
using WebApi.Interface;
using WebApi.Models;

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
            lista.Add(new ReglaDecision
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
            });
        }

        return lista;
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
        var reglas = new (string Cultivo, string Evento, string NivelRiesgo, string Accion1, string Accion2, string Accion3, string Descripcion)[]
        {
            ("Maiz", "Lluvia intensa", "Alto",
                "Revisar y despejar los drenajes de la parcela para evitar encharcamiento",
                "Evitar encharcamiento prolongado que favorece la pudricion de raiz",
                "Monitorear las plantas por sintomas de pudricion tras el evento de lluvia",
                "PRELIMINAR: el exceso de agua satura el suelo y favorece pudricion de raiz y riesgo de acame en el maizal. Pendiente de validacion tecnica."),

            ("Frijol", "Canicula", "Alto",
                "Aplicar cobertura vegetal (mulching) o barreras vivas para conservar humedad del suelo",
                "Priorizar riego de auxilio en horas de la manana o tarde si hay sistema disponible",
                "Evitar labores que remuevan el suelo y aceleren la perdida de humedad",
                "PRELIMINAR: el frijol es sensible al estres hidrico, sobre todo en floracion y llenado de vaina. Pendiente de validacion tecnica."),

            ("Maiz", "Viento fuerte", "Alto",
                "Revisar el estado de cortinas rompevientos si existen en la parcela",
                "Evaluar el aporque (acumulacion de tierra en la base del tallo) para dar mayor sujecion a la planta",
                "Posponer aplicaciones foliares hasta que baje el viento",
                "PRELIMINAR: el acame (volcamiento del tallo) es uno de los riesgos mas documentados del maiz frente a viento fuerte. Pendiente de validacion tecnica."),

            ("Frijol", "Lluvia intensa", "Alto",
                "Verificar drenajes y evitar encharcamiento en la parcela",
                "Suspender fertilizacion nitrogenada hasta que el suelo drene",
                "Monitorear sintomas de pudricion de raiz y enfermedades fungosas",
                "PRELIMINAR: el exceso de agua favorece la pudricion de raiz, sobre todo en suelos de mal drenaje. Pendiente de validacion tecnica."),

            ("Maiz", "Canicula", "Alto",
                "Priorizar riego de auxilio en horas de la manana o tarde si hay sistema disponible",
                "Mantener cobertura de rastrojo sobre el suelo para conservar humedad",
                "Evitar labores de cultivo que remuevan el suelo durante el periodo de sequia",
                "PRELIMINAR: la floracion y el llenado de grano son las etapas mas criticas del maiz frente al estres hidrico. Pendiente de validacion tecnica."),
        };

        using var connection = _connectionBD.CrearConexion();
        await connection.OpenAsync();

        foreach (var regla in reglas)
        {
            using var command = new SqlCommand(
                @"UPDATE rd
                  SET NivelRiesgo = @NivelRiesgo, Accion1 = @Accion1, Accion2 = @Accion2,
                      Accion3 = @Accion3, DescripcionAlerta = @Descripcion
                  FROM ReglasDecision rd
                  JOIN Cultivos c ON c.Id = rd.CultivoId
                  JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
                  WHERE c.Nombre = @Cultivo AND ec.Nombre = @Evento", connection);

            command.Parameters.AddWithValue("@NivelRiesgo", regla.NivelRiesgo);
            command.Parameters.AddWithValue("@Accion1", regla.Accion1);
            command.Parameters.AddWithValue("@Accion2", regla.Accion2);
            command.Parameters.AddWithValue("@Accion3", regla.Accion3);
            command.Parameters.AddWithValue("@Descripcion", regla.Descripcion);
            command.Parameters.AddWithValue("@Cultivo", regla.Cultivo);
            command.Parameters.AddWithValue("@Evento", regla.Evento);

            await command.ExecuteNonQueryAsync();
        }
    }
}