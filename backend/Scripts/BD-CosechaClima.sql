CREATE DATABASE BD_CosechaClima;
GO

USE BD_CosechaClima;
GO

-- tablas de catalogo

CREATE TABLE TipoSuelo (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(200) NULL
);

CREATE TABLE Cultivos (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    NombreCientifico NVARCHAR(100) NULL
);

CREATE TABLE EtapaFenologica (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(100) NULL,
    DiasDesdeSiembra INT NULL
);

CREATE TABLE EventoClimatico (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(200) NULL
);

-- tablas de negocio

CREATE TABLE Usuarios (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Telefono NVARCHAR(20) NOT NULL UNIQUE,
    PinHash NVARCHAR(200) NOT NULL,
    PinSalt NVARCHAR(100) NOT NULL,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Activo BIT DEFAULT 1
);

CREATE TABLE Parcelas (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL,
    CultivoId INT NOT NULL,
    EtapaFenologicaId INT NULL,
    TipoSueloId INT NOT NULL,
    FechaSiembra DATE NOT NULL,
    AreaMzs DECIMAL(5,2) NOT NULL,
    Latitud DECIMAL(9,6) NULL,
    Longitud DECIMAL(9,6) NULL,
    Municipio NVARCHAR(100) NULL,
    Comunidad NVARCHAR(100) NULL,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Activa BIT DEFAULT 1,
    CONSTRAINT FK_Parcela_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id),
    CONSTRAINT FK_Parcela_Cultivo FOREIGN KEY (CultivoId) REFERENCES Cultivos(Id),
    CONSTRAINT FK_Parcela_Etapa FOREIGN KEY (EtapaFenologicaId) REFERENCES EtapaFenologica(Id),
    CONSTRAINT FK_Parcela_Suelo FOREIGN KEY (TipoSueloId) REFERENCES TipoSuelo(Id)
);

CREATE TABLE UmbralConfiguracion (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL UNIQUE,
    LluviaIntensaMm INT DEFAULT 100,
    VientoFuerteKmh INT DEFAULT 40,
    CaniculaDias INT DEFAULT 7,
    VariedadCultivo NVARCHAR(50) DEFAULT 'Criollo',
    TieneRiego BIT DEFAULT 0,
    HorarioSms TIME DEFAULT '06:00',
    CONSTRAINT FK_Umbral_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id)
);

CREATE TABLE DatosClimaticos (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ParcelaId INT NOT NULL,
    Fecha DATE NOT NULL,
    TemperaturaMedia DECIMAL(5,1) NULL,
    TemperaturaMax DECIMAL(5,1) NULL,
    TemperaturaMin DECIMAL(5,1) NULL,
    Precipitacion DECIMAL(6,2) NULL,
    HumedadRelativa DECIMAL(5,1) NULL,
    VientoVelocidad DECIMAL(5,1) NULL,
    RadiacionSolar DECIMAL(7,2) NULL,
    FuenteNASA NVARCHAR(50) DEFAULT 'POWER',
    FechaDescarga DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Datos_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id)
);

-- guarda el estado completo del dia
CREATE TABLE BitacoraCampo (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL,
    ParcelaId INT NOT NULL,
    Fecha DATE NOT NULL,
    EventoClimaticoId INT NOT NULL,
    NivelRiesgo NVARCHAR(20) NOT NULL,
    Accion1Texto NVARCHAR(500) NOT NULL,
    Accion2Texto NVARCHAR(500) NOT NULL,
    Accion3Texto NVARCHAR(500) NOT NULL,
    Accion1Completada BIT DEFAULT 0,
    Accion2Completada BIT DEFAULT 0,
    Accion3Completada BIT DEFAULT 0,
    Notas NVARCHAR(MAX) NULL,
    Sincronizado BIT DEFAULT 0,
    FechaSincronizacion DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Bitacora_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id),
    CONSTRAINT FK_Bitacora_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id),
    CONSTRAINT FK_Bitacora_Evento FOREIGN KEY (EventoClimaticoId) REFERENCES EventoClimatico(Id)
);

CREATE TABLE ReglasDecision (
    Id INT PRIMARY KEY IDENTITY(1,1),
    EventoClimaticoId INT NOT NULL,
    CultivoId INT NOT NULL,
    EtapaFenologicaId INT NOT NULL,
    TipoSueloId INT NOT NULL,
    NivelRiesgo NVARCHAR(20) NOT NULL,
    Accion1 NVARCHAR(500) NOT NULL,
    Accion2 NVARCHAR(500) NOT NULL,
    Accion3 NVARCHAR(500) NOT NULL,
    DescripcionAlerta NVARCHAR(500) NOT NULL,
    CONSTRAINT FK_ReglaEvento FOREIGN KEY (EventoClimaticoId) REFERENCES EventoClimatico(Id),
    CONSTRAINT FK_Regla_Cultivo FOREIGN KEY (CultivoId) REFERENCES Cultivos(Id),
    CONSTRAINT FK_Regla_Etapa FOREIGN KEY (EtapaFenologicaId) REFERENCES EtapaFenologica(Id),
    CONSTRAINT FK_Regla_Suelo FOREIGN KEY (TipoSueloId) REFERENCES TipoSuelo(Id)
);

-- para fase 2 reportes comunitarios
CREATE TABLE ReportesComunitarios (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL,
    Municipio NVARCHAR(100) NOT NULL,
    Sintomas NVARCHAR(500) NOT NULL,
    FechaReporte DATETIME DEFAULT GETDATE(),
    Latitud DECIMAL(10,6) NOT NULL,
    Longitud DECIMAL(10,6) NOT NULL,
    CONSTRAINT FK_Reporte_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id)
);

-- tablas catalogo 

INSERT INTO TipoSuelo (Nombre, Descripcion) VALUES
('Franco',    'Textura equilibrada, buen drenaje y retencion de nutrientes'),
('Arcilloso', 'Alta retencion de humedad, susceptible a encharcamiento'),
('Arenoso',   'Drenaje rapido, vulnerable a sequia y lixiviacion');

INSERT INTO Cultivos (Nombre, NombreCientifico) VALUES
('Maiz',  'Zea mays'),
('Frijol', 'Phaseolus vulgaris');

INSERT INTO EtapaFenologica (Nombre, Descripcion, DiasDesdeSiembra) VALUES
('Germinacion',          'De la siembra a la emergencia',              0),
('Plantula',             'De 2 a 4 hojas verdaderas',                 11),
('Desarrollo vegetativo', 'Crecimiento de tallo y hojas',              26),
('Floracion',            'Emision de inflorescencias y polinizacion', 56),
('Llenado de grano',     'Formacion y llenado del fruto',             71),
('Maduracion',           'Madurez fisiologica a cosecha',             91);

INSERT INTO EventoClimatico (Nombre, Descripcion) VALUES
('Lluvia intensa',    'Precipitacion superior al umbral configurado en 24 horas'),
('Canicula',          'Periodo prolongado sin lluvia que supera el umbral'),
('Viento fuerte',     'Velocidad del viento superior al umbral configurado'),
('Temperatura extrema', 'Temperatura fuera del rango optimo para el cultivo'),
('Riesgo de helada',  'Temperatura cercana a 0C que puede dañar el cultivo');

GO
