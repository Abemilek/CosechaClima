-- Catalogos base. Los ids se asignan en este orden y el motor de decisiones
-- (EventoClimaticoId.cs en el backend y MotorLocal en la app) depende de el.
-- Idempotente: ON CONFLICT sobre las columnas nombre (UNIQUE).

INSERT INTO tipos_suelo (nombre, descripcion) VALUES
    ('Franco',    'Textura equilibrada, buen drenaje y retención de nutrientes'),
    ('Arcilloso', 'Alta retención de humedad, susceptible a encharcamiento'),
    ('Arenoso',   'Drenaje rápido, vulnerable a sequía y lixiviación')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO cultivos (nombre, nombre_cientifico) VALUES
    ('Maíz',   'Zea mays'),
    ('Frijol', 'Phaseolus vulgaris'),
    ('Arroz',  'Oryza sativa'),
    ('Sorgo',  'Sorghum bicolor'),
    ('Café',   'Coffea arabica')
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO etapas_fenologicas (nombre, descripcion, dias_desde_siembra) VALUES
    ('Germinación',           'De la siembra a la emergencia',        0),
    ('Plántula',              'De 2 a 4 hojas verdaderas',            11),
    ('Desarrollo vegetativo', 'Crecimiento de tallo y hojas',         26),
    ('Floración',             'Emisión de flores y polinización',     56),
    ('Llenado de grano',      'Formación y llenado del fruto/grano',  71),
    ('Maduración',            'Madurez fisiológica a cosecha',        91)
ON CONFLICT (nombre) DO NOTHING;

INSERT INTO eventos_climaticos (nombre, descripcion) VALUES
    ('Lluvia intensa',      'Precipitación superior al umbral configurado en 24 horas'),
    ('Canícula',            'Período prolongado sin lluvia que supera el umbral'),
    ('Viento fuerte',       'Velocidad del viento superior al umbral configurado'),
    ('Temperatura extrema', 'Temperatura fuera del rango óptimo para el cultivo'),
    ('Riesgo de helada',    'Temperatura cercana a 0C que puede dañar el cultivo'),
    ('Sin riesgo',          'Ningún umbral configurado fue superado, condiciones normales')
ON CONFLICT (nombre) DO NOTHING;
