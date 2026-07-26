USE BD_CosechaClima;
GO

-- Genera automaticamente todas las combinaciones posibles y las deja
-- con texto placeholder. El tecnico del INTA llena el contenido real
-- despues via UPDATE

INSERT INTO ReglasDecision (EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId,
    NivelRiesgo, Accion1, Accion2, Accion3, DescripcionAlerta)
SELECT
    ec.Id,
    c.Id,
    ef.Id,
    ts.Id,
    'PENDIENTE',
    'PENDIENTE - definir con tecnico INTA',
    'PENDIENTE - definir con tecnico INTA',
    'PENDIENTE - definir con tecnico INTA',
    CONCAT('Regla generada automaticamente para ', ec.Nombre, ' / ', c.Nombre, ' / ', ef.Nombre, ' / ', ts.Nombre)
FROM EventoClimatico ec
CROSS JOIN Cultivos c
CROSS JOIN EtapaFenologica ef
CROSS JOIN TipoSuelo ts
WHERE NOT EXISTS (
    SELECT 1 FROM ReglasDecision rd
    WHERE rd.EventoClimaticoId = ec.Id
      AND rd.CultivoId = c.Id
      AND rd.EtapaFenologicaId = ef.Id
      AND rd.TipoSueloId = ts.Id
);
GO

SELECT COUNT(*) AS TotalReglas FROM ReglasDecision;
GO