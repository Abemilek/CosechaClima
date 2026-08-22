USE BD_CosechaClima;
GO

IF NOT EXISTS (SELECT 1 FROM TipoSuelo)
BEGIN
    INSERT INTO TipoSuelo (Nombre, Descripcion) VALUES
    ('Franco',    'Textura equilibrada, buen drenaje y retencion de nutrientes'),
    ('Arcilloso', 'Alta retencion de humedad, susceptible a encharcamiento'),
    ('Arenoso',   'Drenaje rapido, vulnerable a sequia y lixiviacion');
END;
GO

IF NOT EXISTS (SELECT 1 FROM Cultivos)
BEGIN
    INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES
    ('Maiz',   'Zea mays'),
    ('Frijol', 'Phaseolus vulgaris');
END;
GO

IF NOT EXISTS (SELECT 1 FROM EtapaFenologica)
BEGIN
    INSERT INTO EtapaFenologica (Nombre, Descripcion, DiasDesdeSiembra) VALUES
    ('Germinacion',           'De la siembra a la emergencia',              0),
    ('Plantula',              'De 2 a 4 hojas verdaderas',                 11),
    ('Desarrollo vegetativo', 'Crecimiento de tallo y hojas',               26),
    ('Floracion',             'Emision de flores y polinizacion',           56),
    ('Llenado de grano',      'Formacion y llenado del fruto/grano',        71),
    ('Maduracion',            'Madurez fisiologica a cosecha',              91);
END;
GO

IF NOT EXISTS (SELECT 1 FROM EventoClimatico)
BEGIN
    INSERT INTO EventoClimatico (Nombre, Descripcion) VALUES
    ('Lluvia intensa',      'Precipitacion superior al umbral configurado en 24 horas'),
    ('Canicula',            'Periodo prolongado sin lluvia que supera el umbral'),
    ('Viento fuerte',       'Velocidad del viento superior al umbral configurado'),
    ('Temperatura extrema', 'Temperatura fuera del rango optimo para el cultivo'),
    ('Riesgo de helada',    'Temperatura cercana a 0C que puede dañar el cultivo'),
    ('Sin riesgo',          'Ningun umbral configurado fue superado, condiciones normales');
END;
GO