USE BD_CosechaClima;GO

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