USE BD_CosechaClima;
GO

INSERT INTO TipoSuelo (Nombre, Descripcion) VALUES
('Franco',    'Textura equilibrada, buen drenaje y retencion de nutrientes'),
('Arcilloso', 'Alta retencion de humedad, susceptible a encharcamiento'),
('Arenoso',   'Drenaje rapido, vulnerable a sequia y lixiviacion');

INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES
('Maiz',   'Zea mays'),
('Frijol', 'Phaseolus vulgaris');

INSERT INTO EtapaFenologica (Nombre, Descripcion, DiasDesdeSiembra) VALUES
('Germinacion',           'De la siembra a la emergencia',              0),
('Plantula',              'De 2 a 4 hojas verdaderas',                 11),
('Desarrollo vegetativo', 'Crecimiento de tallo y hojas',               26),
('Floracion',             'Emision de flores y polinizacion',           56),
('Llenado de grano',      'Formacion y llenado del fruto/grano',        71),
('Maduracion',            'Madurez fisiologica a cosecha',              91);

INSERT INTO EventoClimatico (Nombre, Descripcion) VALUES
('Lluvia intensa',      'Precipitacion superior al umbral configurado en 24 horas'),
('Canicula',            'Periodo prolongado sin lluvia que supera el umbral'),
('Viento fuerte',       'Velocidad del viento superior al umbral configurado'),
('Temperatura extrema', 'Temperatura fuera del rango optimo para el cultivo'),
('Riesgo de helada',    'Temperatura cercana a 0C que puede dañar el cultivo');
GO