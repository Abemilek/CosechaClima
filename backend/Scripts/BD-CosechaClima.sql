IF DB_ID(N'BD_CosechaClima') IS NULL
    CREATE DATABASE BD_CosechaClima;
GO

USE BD_CosechaClima;
GO

SET QUOTED_IDENTIFIER ON;
GO

IF OBJECT_ID(N'dbo.TipoSuelo', N'U') IS NULL
CREATE TABLE TipoSuelo (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(200) NULL
);
GO

IF OBJECT_ID(N'dbo.Cultivos', N'U') IS NULL
CREATE TABLE Cultivos (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    NombreCientifico NVARCHAR(100) NULL
);
GO

IF OBJECT_ID(N'dbo.EtapaFenologica', N'U') IS NULL
CREATE TABLE EtapaFenologica (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(100) NULL,
    DiasDesdeSiembra INT NULL
);
GO

IF OBJECT_ID(N'dbo.EventoClimatico', N'U') IS NULL
CREATE TABLE EventoClimatico (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL,
    Descripcion NVARCHAR(200) NULL
);
GO

IF OBJECT_ID(N'dbo.Usuarios', N'U') IS NULL
CREATE TABLE Usuarios (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Email NVARCHAR(256) NOT NULL UNIQUE,
    GoogleUid NVARCHAR(128) NULL,
    PasswordHash NVARCHAR(200) NULL,
    PasswordSalt NVARCHAR(100) NULL,
    Proveedor TINYINT NOT NULL DEFAULT 0,
    FotoUrl NVARCHAR(500) NULL,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Activo BIT DEFAULT 1,
    EsAdmin BIT NOT NULL DEFAULT 0,
    CONSTRAINT CK_Usuarios_Credenciales CHECK (
        (Proveedor = 0 AND PasswordHash IS NOT NULL AND PasswordSalt IS NOT NULL)
        OR
        (Proveedor = 1 AND GoogleUid IS NOT NULL)
    )
);
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UQ_Usuarios_GoogleUid'
      AND object_id = OBJECT_ID(N'dbo.Usuarios')
)
CREATE UNIQUE INDEX UQ_Usuarios_GoogleUid ON Usuarios(GoogleUid)
WHERE GoogleUid IS NOT NULL;
GO

IF OBJECT_ID(N'dbo.Parcelas', N'U') IS NULL
CREATE TABLE Parcelas (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL,
    CultivoId INT NOT NULL,
    EtapaFenologicaId INT NULL,
    TipoSueloId INT NOT NULL,
    FechaSiembra DATE NOT NULL,
    AreaMzs DECIMAL(7,2) NOT NULL,
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
GO

IF OBJECT_ID(N'dbo.UmbralConfiguracion', N'U') IS NULL
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
GO

IF OBJECT_ID(N'dbo.DatosClimaticos', N'U') IS NULL
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
    FuenteClima NVARCHAR(50) DEFAULT 'OPEN_METEO',
    FechaDescarga DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Datos_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id),
    CONSTRAINT UK_Datos_Parcela_Fecha UNIQUE (ParcelaId, Fecha)
);
GO

IF OBJECT_ID(N'dbo.BitacoraCampo', N'U') IS NULL
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
GO

IF OBJECT_ID(N'dbo.ReglasDecision', N'U') IS NULL
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
GO

IF NOT EXISTS (
    SELECT 1 FROM sys.indexes
    WHERE name = N'UK_ReglasDecision_Clave'
      AND object_id = OBJECT_ID(N'dbo.ReglasDecision')
)
CREATE UNIQUE INDEX UK_ReglasDecision_Clave
    ON ReglasDecision (EventoClimaticoId, CultivoId, EtapaFenologicaId, TipoSueloId);
GO

IF OBJECT_ID(N'dbo.ReportesComunitarios', N'U') IS NULL
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
GO

IF OBJECT_ID(N'dbo.Alertas', N'U') IS NULL
CREATE TABLE Alertas (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL,
    ParcelaId INT NOT NULL,
    Fecha DATE NOT NULL,
    EventoClimaticoId INT NOT NULL,
    NivelRiesgo NVARCHAR(20) NOT NULL,
    Accion1 NVARCHAR(500) NOT NULL,
    Accion2 NVARCHAR(500) NOT NULL,
    Accion3 NVARCHAR(500) NOT NULL,
    DescripcionAlerta NVARCHAR(500) NOT NULL,
    FechaGeneracion DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Alerta_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id),
    CONSTRAINT FK_Alerta_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id),
    CONSTRAINT FK_Alerta_Evento FOREIGN KEY (EventoClimaticoId) REFERENCES EventoClimatico(Id),
    CONSTRAINT UK_Alerta_Parcela_Fecha UNIQUE (ParcelaId, Fecha)
);
GO