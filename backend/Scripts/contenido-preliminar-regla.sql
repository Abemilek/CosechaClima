USE BD_CosechaClima;
GO

-- Regla 1: Maiz + Lluvia intensa
UPDATE rd
SET NivelRiesgo = 'Alto',
    Accion1 = 'Revisar y despejar los drenajes de la parcela para evitar encharcamiento',
    Accion2 = 'Evitar encharcamiento prolongado que favorece la pudricion de raiz',
    Accion3 = 'Monitorear las plantas por sintomas de pudricion tras el evento de lluvia',
    DescripcionAlerta = 'PRELIMINAR: el exceso de agua satura el suelo y favorece pudricion de raiz y riesgo de acame en el maizal. Pendiente de validacion tecnica.'
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE c.Nombre = 'Maiz' AND ec.Nombre = 'Lluvia intensa';

-- Regla 2: Frijol + Canicula
UPDATE rd
SET NivelRiesgo = 'Alto',
    Accion1 = 'Aplicar cobertura vegetal (mulching) o barreras vivas para conservar humedad del suelo',
    Accion2 = 'Priorizar riego de auxilio en horas de la manana o tarde si hay sistema disponible',
    Accion3 = 'Evitar labores que remuevan el suelo y aceleren la perdida de humedad',
    DescripcionAlerta = 'PRELIMINAR: el frijol es sensible al estres hidrico, sobre todo en floracion y llenado de vaina. Pendiente de validacion tecnica.'
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE c.Nombre = 'Frijol' AND ec.Nombre = 'Canicula';

-- Regla 3: Maiz + Viento fuerte
UPDATE rd
SET NivelRiesgo = 'Alto',
    Accion1 = 'Revisar el estado de cortinas rompevientos si existen en la parcela',
    Accion2 = 'Evaluar el aporque (acumulacion de tierra en la base del tallo) para dar mayor sujecion a la planta',
    Accion3 = 'Posponer aplicaciones foliares hasta que baje el viento',
    DescripcionAlerta = 'PRELIMINAR: el acame (volcamiento del tallo) es uno de los riesgos mas documentados del maiz frente a viento fuerte. Pendiente de validacion tecnica.'
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE c.Nombre = 'Maiz' AND ec.Nombre = 'Viento fuerte';

-- Regla 4: Frijol + Lluvia intensa
UPDATE rd
SET NivelRiesgo = 'Alto',
    Accion1 = 'Verificar drenajes y evitar encharcamiento en la parcela',
    Accion2 = 'Suspender fertilizacion nitrogenada hasta que el suelo drene',
    Accion3 = 'Monitorear sintomas de pudricion de raiz y enfermedades fungosas',
    DescripcionAlerta = 'PRELIMINAR: el exceso de agua favorece la pudricion de raiz, sobre todo en suelos de mal drenaje. Pendiente de validacion tecnica.'
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE c.Nombre = 'Frijol' AND ec.Nombre = 'Lluvia intensa';

-- Regla 5: Maiz + Canicula
UPDATE rd
SET NivelRiesgo = 'Alto',
    Accion1 = 'Priorizar riego de auxilio en horas de la manana o tarde si hay sistema disponible',
    Accion2 = 'Mantener cobertura de rastrojo sobre el suelo para conservar humedad',
    Accion3 = 'Evitar labores de cultivo que remuevan el suelo durante el periodo de sequia',
    DescripcionAlerta = 'PRELIMINAR: la floracion y el llenado de grano son las etapas mas criticas del maiz frente al estres hidrico. Pendiente de validacion tecnica.'
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE c.Nombre = 'Maiz' AND ec.Nombre = 'Canicula';
GO

-- Confirmar que las 5 reglas quedaron actualizadas (deberian aparecer con NivelRiesgo distinto de 'PENDIENTE')
SELECT rd.Id, c.Nombre AS Cultivo, ec.Nombre AS Evento, rd.NivelRiesgo, rd.DescripcionAlerta
FROM ReglasDecision rd
JOIN Cultivos c ON c.Id = rd.CultivoId
JOIN EventoClimatico ec ON ec.Id = rd.EventoClimaticoId
WHERE rd.NivelRiesgo <> 'PENDIENTE';
GO