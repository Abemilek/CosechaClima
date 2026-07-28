USE BD_CosechaClima;
GO

-- debe quedar en id 6 pues para que conicida con el modelo de c$ de enum
INSERT INTO EventoClimatico (Nombre, Descripcion) VALUES
('Sin riesgo', 'Ningun umbral configurado fue superado, condiciones normales');
GO

-- generar las reglas placeholder
INSERT INTO ReglasDecision (EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId,
    NivelRiesgo, Accion1, Accion2, Accion3, DescripcionAlerta)
SELECT
    ec.Id, c.Id, ef.Id, ts.Id,
    'Bajo',
    'Continuar con el manejo habitual del cultivo',
    'Revisar la parcela de forma rutinaria',
    'No se requiere accion inmediata',
    CONCAT('Condiciones normales para ', c.Nombre, ' en etapa ', ef.Nombre)
FROM EventoClimatico ec
CROSS JOIN Cultivos c
CROSS JOIN EtapaFenologica ef
CROSS JOIN TipoSuelo ts
WHERE ec.Nombre = 'Sin riesgo'
  AND NOT EXISTS (
      SELECT 1 FROM ReglasDecision rd
      WHERE rd.EventoClimaticoId = ec.Id
        AND rd.CultivoId = c.Id
        AND rd.EtapaFenologicaId = ef.Id
        AND rd.TipoSueloId = ts.Id
  );
GO