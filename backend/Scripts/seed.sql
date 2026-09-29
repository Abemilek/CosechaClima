USE BD_CosechaClima;
GO

IF NOT EXISTS (SELECT 1 FROM TipoSuelo)
BEGIN
    INSERT INTO TipoSuelo (Nombre, Descripcion) VALUES
    ('Franco',    'Textura equilibrada, buen drenaje y retención de nutrientes'),
    ('Arcilloso', 'Alta retención de humedad, susceptible a encharcamiento'),
    ('Arenoso',   'Drenaje rápido, vulnerable a sequía y lixiviación');
END;
GO

IF NOT EXISTS (SELECT 1 FROM Cultivos)
BEGIN
    INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES
    ('Maíz',   'Zea mays'),
    ('Frijol', 'Phaseolus vulgaris'),
    ('Arroz',  'Oryza sativa'),
    ('Sorgo',  'Sorghum bicolor'),
    ('Café',   'Coffea arabica');
END;
GO

IF NOT EXISTS (SELECT 1 FROM Cultivos WHERE Nombre = 'Arroz')
    INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES ('Arroz', 'Oryza sativa');
IF NOT EXISTS (SELECT 1 FROM Cultivos WHERE Nombre = 'Sorgo')
    INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES ('Sorgo', 'Sorghum bicolor');
IF NOT EXISTS (SELECT 1 FROM Cultivos WHERE Nombre = 'Café')
    INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES ('Café', 'Coffea arabica');
GO

IF NOT EXISTS (SELECT 1 FROM EtapaFenologica)
BEGIN
    INSERT INTO EtapaFenologica (Nombre, Descripcion, DiasDesdeSiembra) VALUES
    ('Germinación',           'De la siembra a la emergencia',              0),
    ('Plántula',              'De 2 a 4 hojas verdaderas',                 11),
    ('Desarrollo vegetativo', 'Crecimiento de tallo y hojas',               26),
    ('Floración',             'Emisión de flores y polinización',           56),
    ('Llenado de grano',      'Formación y llenado del fruto/grano',        71),
    ('Maduración',            'Madurez fisiológica a cosecha',              91);
END;
GO

IF NOT EXISTS (SELECT 1 FROM EventoClimatico)
BEGIN
    INSERT INTO EventoClimatico (Nombre, Descripcion) VALUES
    ('Lluvia intensa',      'Precipitación superior al umbral configurado en 24 horas'),
    ('Canícula',            'Período prolongado sin lluvia que supera el umbral'),
    ('Viento fuerte',       'Velocidad del viento superior al umbral configurado'),
    ('Temperatura extrema', 'Temperatura fuera del rango óptimo para el cultivo'),
    ('Riesgo de helada',    'Temperatura cercana a 0C que puede dañar el cultivo'),
    ('Sin riesgo',          'Ningún umbral configurado fue superado, condiciones normales');
END;
GO