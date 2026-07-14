CREATE DATABASE BD_CosechaClima;
GO

USE BD_CosechaClima;
GO

CREATE TABLE TipoSuelo (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL, --nombre del suelo, puede ser franco, arcilloso o arenoso
    Descripcion NVARCHAR(200) NULL --explicacion de como es el suelo
);

CREATE TABLE Cultivos (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL, --aqui seria maiz y frijol segun como se definio en el documento
    NombreCientifico NVARCHAR(100) NULL
);

--esta seria para el monitoreo de las etapas que pasa el cultivo desde la siempbra hasta la cosecha
CREATE TABLE EtapaFenologica (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL, -- germinacion etc
    Descripcion NVARCHAR(100) NULL,
    DiasDesdeSiembra INT NULL -- a los cuantos dias
);

--esta es para los evento climaticos que puede detectar la app
CREATE TABLE EventoClimatico (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(50) NOT NULL, --lluvia, viento etc
    Descripcion NVARCHAR(200) NULL
);

CREATE TABLE Usuarios (
    Id INT PRIMARY KEY IDENTITY(1,1),
    Nombre NVARCHAR(100) NOT NULL,
    Telefono NVARCHAR(20) NOT NULL UNIQUE, --unique pues no puede haber 2 numeros iguales
    PinHash NVARCHAR(200) NOT NULL, -- sera el pin cifrado
    PinSalt NVARCHAR(100) NOT NULL, -- para los datos aleatorios
    FechaRegistro DATETIME DEFAULT GETDATE(), -- cuando se registro
    Activo BIT DEFAULT 1
);

-- esta se diferencia en que almacenara los datos del usuario, 1 usuario es un productor
CREATE TABLE Productores (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL UNIQUE, -- fk cada productor es un usuario
    Departamento NVARCHAR(100) DEFAULT 'Carazo', -- pues la app es de carazo
    Municipio NVARCHAR(100) NOT NULL, -- en el doc de definio diriamba, jinotepe, dolores y san marxos
    Comunidad NVARCHAR(100) NULL,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Productor_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id)
);

-- estas serian las parcelas que puede tener un productor y pues puede tener muchas
CREATE TABLE Parcelas (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ProductorId INT NOT NULL, -- a que productor pertenece
    CultivoId INT NOT NULL, -- maiz o frijol que se delimito en el doc
    EtapaFenologicaId INT NULL, -- esta seria la etapa que esta
    TipoSueloId INT NOT NULL, --  arcilloso, arenoso etc
    FechaSiembra DATE NOT NULL, -- cuando sembor
    AreaMzs DECIMAL(5,2) NOT NULL, -- area en manzanas
    Latitud DECIMAL(9,0) NULL, -- latitud gps
    Longitud DECIMAL(9,6) NULL, -- longitud gps
    FechaRegistro DATETIME DEFAULT GETDATE(),
    Activa BIT DEFAULT 1,
    CONSTRAINT FK_Parcela_Productor FOREIGN KEY (ProductorId) REFERENCES Prductores(Id),
    CONSTRAINT FK_Parcela_Cultivo FOREIGN KEY (CultivoId) REFERENCES CultivosId(Id),
    CONSTRAINT FK_Parcela_Etapa FOREIGN KEY (EtapaFenologicaId) REFERENCES EtapaFenologica(Id),
    CONSTRAINT FK_Parcela_Suelo FOREIGN kEY (TipoSueloId) REFERENCES TipoSuelo(Id)
);

-- cada productor tiene una configuarcion diferente
CREATE TABLE UmbralConfiguracion (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ProductorId INT NOT NULL UNIQUE, -- pues cada productor tiene su propia configuracion
    LluviaIntensaMm INT DEFAULT 100, -- a partir de cuantos mm es intensa
    VientoFuerteKmh INT DEFAULT 40, -- a parti de cuantos km por hora
    CaniculaDias INT DEFAULT 7, -- a partir de cuantos dias sin llover
    VariedadCultivo NVARCHAR(50) DEFAULT 'Criollo', -- criollo hibrido y mejorado
    TieneRiego BIT DEFAULT 0, -- 1 pues si tiene sistema de riego
    HorarioSms TIME DEFAULT '06:00', -- a que hora quiere las alertas
    CONSTRAINT FK_Umbral_Productor FOREIGN KEY (ProductorId) REFERENCES Productores(Id)
);

-- aqui descargamos los datos de la api de la nasa
CREATE TABLE DatosClimaticos (
    Id INT PRIMARY KEY IDENTITY(1,1),
    ParcelaId INT NOT NULL, -- para que parcela son los datos
    Fecha DATE NOT NULL, -- el dia de los datos
    TemperaturaMedia DECIMAL(5,1) NULL, --
    TemperaturaMax DECIMAL(5,1) NULL, --
    TemperaturaMin DECIMAL(5,1) NULL, --
    Precipitacion DECIMAL(6,2) NULL,
    HumedadRelativa DECIMAL(5,1) NULL, --
    VientoVelocidad DECIMAL(5,1) NULL, --
    RadiacionSolar DECIMAL(7,2) NULL, --
    FuenteNASA NVARCHAR(50) DEFAULT 'POWER', -- fuente de los datos
    FechaDescarga DATETIME DEFAULT GETDATE(), -- y cuando se descargaron los datos
    CONSTRAINT FK_Datos_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id)
);

CREATE TABLE Alertas (
    Id INT PRIMARY KEY IDENTITY(1,1),
    UsuarioId INT NOT NULL, -- a que usuario se dirige la alerta
    ParcelaId INT NOT NULL, -- etc
    FechaGeneracion DATETIME DEFAULT GETDATE(), -- cuando se genero
    FechaAlerta DATE NOT NULL, 
    NivelRiesgo NVARCHAR(20) NOT NULL, -- verde amarillo orojo
    EventoClimaticoId INT NOT NULL, -- lluvia canicula etc
    Descripcion NVARCHAR(500) NOT NULL, --riesgo d paleo etc
    Semaforo NVARCHAR(20) NOT NULL, -- verde amarillo rojo
    Leida BIT DEFAULT 0, -- marcada como vista por el user
    SmsEnviado BIT DEFAULT 0, -- si se envio o preparo
    CONSTRAINT FK_Alerta_Usuario FOREIGN KEY (UsuarioId) REFERENCES Usuarios(Id),
    CONSTRAINT FK_Alerta_Parcela FOREIGN KEY (ParcelaId) REFERENCES Parcelas(Id),
    CONSTRAINT FK_Alerta_Evento FOREIGN KEY (EventoClimaticoId) REFERENCES EventoClimatico(Id)
);

-- las acciones recomendadas que son 3 para cada alerta
CREATE TABLE AccionesRecomendadas(
    Id INT PRIMARY KEY IDENTITY(1,1),
    AlertaId INT NOT NULL, -- pues a que alerta pertenece
    NumeroAccion INT NOT NULL, -- 1 2 3
    Descripcion NVARCHAR(500) NOT NULL, -- revisar drenajes etc
    Completada BIT DEFAULT 0, -- si el usuario ya la hizo
    CONSTRAINT FK_Accion_Alerta FOREIGN KEY (AlertaId) REFERENCES Alertas(Id)
);

-- registro de acciones completadas
CREATE TABLE BitacoraCampo (
    Id INT PRIMARY KEY IDENTITY(1,1),
    AlertaId INT NOT NULL,
    AccionId INT NOT NULL, 
    FechaCompletado DATETIME DEFAULT GETDATE(),
    Notas NVARCHAR(MAX) NULL, -- opcional para el user
    CONSTRAINT FK_Bitacora_Alerta FOREIGN KEY (AlertaId) REFERENCES Alertas(Id),
    CONSTRAINT FK_Bitaora_Accion FOREIGN KEY (AccionId) REFERENCES AccionesRecomendadas(Id)
);

-- reglad de decisiones
CREATE TABLE ReglasDecision (
    Id INT PRIMARY KEY IDENTITY(1,1),
    EventoClimaticoId INT NOT NULL, -- lluvia, canicula etc
    CultivoId INT NOT NULL, -- maiz, frijol
    EtapaFenologicaId INT NOT NULL, -- germinacion, floracion etc
    TipoSueloId INT NOT NULL, -- etc
    NivelRiesgo NVARCHAR(20) NOT NULL, -- verde rojo amarillo
    Accion1 NVARCHAR(500) NOT NULL, -- primera accion recomenadsd
    Accion2 NVARCHAR(500) NOT NULL,
    Accion3 NVARCHAR(500) NOT NULL,
    DescripcionAlerta NVARCHAR(500) NOT NULL, --el texto de la alerta
    CONSTRAINT FK_ReglaEvento FOREIGN KEY (EventoClimaticoId) REFERENCES EventoClimatico(Id),
    CONSTRAINT FK_Regla_Cultivo FOREIGN KEY (CultivoId) REFERENCES Cultivos(Id),
    CONSTRAINT FK_Regla_Etapa FOREIGN KEY (EtapaFenologicaId) REFERENCES EtapaFenologica(Id),
    CONSTRAINT FK_Regla_Suelo FOREIGN KEY (TipoSueloId) REFERENCES TipoSuelo(Id)
);

-- reportes de plagas, anomalias etc
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
