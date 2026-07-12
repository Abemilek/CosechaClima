# 🌽 CosechaClima — Backend (ASP.NET Core 8)

**CosechaClima** es una aplicación móvil Android que ayuda a pequeños productores agropecuarios de **Carazo, Nicaragua** a proteger sus cosechas de **maíz y frijol** frente al cambio climático. La app consume datos de la NASA (**API POWER**) para generar alertas tempranas y recomendar **3 acciones concretas** para cada día, mostradas mediante un sistema de semáforo (verde / amarillo / rojo).

Este repositorio contiene el **backend** de la aplicación: el servidor construido en **ASP.NET Core 8** que almacena los datos de los agricultores, se comunica con la NASA POWER y aplica el motor de decisiones (árbol de 90 reglas) que genera las recomendaciones diarias.

---

## 🏗️ Arquitectura en 4 Capas

El backend sigue una arquitectura en capas, donde cada una solo puede depender de las capas inferiores:

```
┌─────────────────────────────────────┐
│  API (Controladores)                │ ← Capa 4: Recibe peticiones de la app
│  CosechaClima.Api                   │
├─────────────────────────────────────┤
│  Servicios (Implementación)         │ ← Capa 3: Lógica de negocio
│  CosechaClima.Implementacion        │
├─────────────────────────────────────┤
│  Interfaces de Servicio             │ ← Capa 2: Contratos/reglas
│  CosechaClima.Interfaz              │
├─────────────────────────────────────┤
│  Modelos de Datos                   │ ← Capa 1: Clases que representan datos
│  CosechaClima.Modelo                │
└─────────────────────────────────────┘
```

- **Capa 1 — Modelo**: clases POCO que representan las tablas de la base de datos.
- **Capa 2 — Interfaz**: contratos que definen qué operaciones existen.
- **Capa 3 — Implementación**: código real con ADO.NET y SQL.
- **Capa 4 — API**: controladores que exponen los endpoints REST para la app Flutter.

### Flujo de una petición típica

```
App Flutter          Backend C#                 NASA POWER
   │ GET /api/motor/semaforo │                       │
   │────────────────────────>│                       │
   │                Busca usuario en BD              │
   │                Obtiene parcela/cultivo           │
   │                GET api.nasa.power.gov ─────────>│
   │                <───────────────────────── clima │
   │                Aplica las 90 reglas              │
   │                Guarda alerta en BD                │
   │ <──── JSON: semáforo + 3 acciones ───────────────│
```

---

## 📁 Estructura del Proyecto

```
/
├── CosechaClima.sln                  # Archivo de solución
├── Dockerfile                        # Docker para la API
├── docker-compose.yml                # Docker para SQL Server + API
├── .gitignore
│
├── CosechaClima.Modelo/              # Capa 1: Modelos de datos
│   ├── Usuario.cs
│   ├── Productor.cs
│   ├── Parcela.cs
│   ├── Cultivo.cs
│   ├── EtapaFenologica.cs
│   ├── TipoSuelo.cs
│   ├── UmbralConfiguracion.cs
│   ├── Alerta.cs
│   ├── AccionRecomendada.cs
│   ├── AccionCompletada.cs
│   ├── BitacoraCampo.cs
│   ├── DatosClimaticos.cs
│   ├── ReglaDecision.cs
│   └── ReporteComunitario.cs
│
├── Services/
│   ├── CosechaClima.Interfaz/        # Capa 2: Interfaces de servicio
│   │   ├── IUsuarioService.cs
│   │   ├── IProductorService.cs
│   │   ├── IParcelaService.cs
│   │   ├── IAlertaService.cs
│   │   ├── IUmbralConfiguracionService.cs
│   │   ├── IDatosClimaticoService.cs
│   │   ├── IBitacoraService.cs
│   │   ├── IReglaDecisionService.cs
│   │   └── IMotorDecisionesService.cs
│   │
│   └── CosechaClima.Implementacion/  # Capa 3: Implementación de servicios
│       ├── UsuarioService.cs
│       ├── ProductorService.cs
│       ├── ParcelaService.cs
│       ├── AlertaService.cs
│       ├── UmbralConfiguracionService.cs
│       ├── DatosClimaticoService.cs
│       ├── BitacoraService.cs
│       ├── ReglaDecisionService.cs
│       ├── MotorDecisionesService.cs
│       └── NasaPowerService.cs        # Cliente para llamar a la NASA
│
├── CosechaClima.Api/                  # Capa 4: API (Controladores)
│   ├── Program.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── Controllers/
│   │   ├── UsuarioController.cs
│   │   ├── ProductorController.cs
│   │   ├── ParcelaController.cs
│   │   ├── AlertaController.cs
│   │   ├── DatosClimaticoController.cs
│   │   ├── UmbralController.cs
│   │   ├── BitacoraController.cs
│   │   ├── MotorDecisionesController.cs
│   │   └── ReporteComunitarioController.cs
│   ├── Dto/
│   │   ├── UsuarioDto.cs
│   │   ├── ProductorDto.cs
│   │   ├── ParcelaDto.cs
│   │   ├── AlertaDto.cs
│   │   ├── AccionDto.cs
│   │   ├── RegistroDto.cs
│   │   ├── LoginDto.cs
│   │   ├── SemafaroDto.cs            # El semáforo + 3 acciones
│   │   └── UmbralDto.cs
│   └── Properties/
│       └── launchSettings.json
│
└── Scripts/                           # Scripts de base de datos
    ├── BD-CosechaClima.sql            # Creación de base de datos y tablas
    ├── DatosIniciales.sql             # Catálogos (tipos de cultivo, suelo, etapas)
    ├── ReglasDecision.sql             # Las 90 reglas del motor
    └── DatosPrueba.sql                # Datos de ejemplo para pruebas
```

---

## 🔧 Prerrequisitos

- [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0)
- Editor de código (VS Code, Visual Studio, Rider, etc.)
- SQL Server (local, Docker, o instancia remota)
- Extensión o cliente para administrar SQL Server (opcional)

Swagger viene integrado en el proyecto, así que no necesitas Postman para probar los endpoints.

---

## 📡 Endpoints principales (ejemplos)

| Verbo | Endpoint | Descripción |
|---|---|---|
| `GET` | `/api/alertas` | Obtener todas las alertas |
| `POST` | `/api/usuarios/registro` | Registrar un nuevo usuario |
| `PUT` | `/api/umbrales/{id}` | Actualizar la configuración del productor |
| `DELETE` | `/api/parcelas/{id}` | Eliminar una parcela |
| `GET` | `/api/motor/semaforo?usuarioId={id}` | Obtener el semáforo (verde/amarillo/rojo) y las 3 acciones del día |