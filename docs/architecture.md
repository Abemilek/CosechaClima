# Architecture

## Diagrama de capas

```
                         ┌──────────────────┐
                         │   App Flutter    │  cliente móvil
                         └────────┬─────────┘
                                  │ HTTPS + JWT
                         ┌────────▼─────────┐
                         │   WebApi (API)   │  Controllers, DTOs, Program.cs
                         └────────┬─────────┘
                         ┌────────▼─────────┐
                         │ WebApi.Interface │  contratos de servicio
                         └────────┬─────────┘
                         ┌────────▼──────────────┐
                         │ WebApi.Implementation  │  logica de negocio + ADO.NET
                         └────────┬───────────────┘
                    ┌─────────────┼──────────────────┐
            ┌───────▼──────┐  ┌───▼────────┐  ┌───────▼────────┐
            │  SQL Server  │  │ Open-Meteo │  │ WebApi.Models   │
            │  (Docker)    │  │  (clima)   │  │ entidades       │
            └──────────────┘  └────────────┘  └─────────────────┘
```

## Principio de diseño: cada capa solo conoce la de abajo, a través de una interfaz

`WebApi.Implementation.MotorDecisionesService`, por ejemplo, no sabe si los datos climáticos vienen de Open-Meteo, de NASA POWER, o de cualquier otra fuente — solo conoce el contrato `IProveedorClimaticoService`. Esto permitió migrar el proveedor climático completo sin tocar el motor de decisiones, los controladores, ni la base de datos.

## Estructura de carpetas

```
backend/
├── WebApi/                          # capa de presentacion HTTP
│   ├── Controllers/
│   ├── Dto/                         # contratos de request/response
│   ├── Extensions/                  # ControllerBaseExtensions (helpers de ownership)
│   ├── ManejadorErroresGlobal.cs    # manejo global de excepciones -> ProblemDetails
│   ├── ChequeoBaseDeDatos.cs        # health check
│   └── Program.cs
├── WebApi.Models/                   # entidades de dominio (una clase = una fila)
├── Services/
│   ├── WebApi.Interface/            # contratos de servicio (lo que WebApi conoce)
│   └── WebApi.Implementation/       # logica de negocio + acceso a datos ADO.NET
│       ├── Connection/              # ConnectionBD (wrapper de SqlConnection)
│       └── Security/                # HashPin, TokenGenerator
├── Scripts/
│   ├── BD-CosechaClima.sql          # esquema (tablas)
│   ├── seed.sql                     # catalogos base (Maiz, Frijol, TipoSuelo, etc)
│   └── reglas-preliminares-completas.json  # contenido del arbol de decision
├── docker-compose.yml
└── Dockerfile
```

## Stack tecnológico

| Capa | Tecnología | Motivo |
|---|---|---|
| Backend | ASP.NET Core (.NET 10) | LTS vigente, tipado fuerte |
| Base de datos | SQL Server 2022 (Docker) | Edición Developer, gratuita para uso no comercial |
| Acceso a datos | ADO.NET puro | Control explícito de cada consulta, sin overhead de ORM para este tamaño de proyecto |
| Autenticación | JWT Bearer + PIN (SHA-256 + salt) | Sin dependencias externas de identidad |
| Autorización | Basada en claims + roles (`Admin`) | Ownership por usuario en cada recurso |
| Datos climáticos | [Open-Meteo](https://open-meteo.com) | Pronóstico real, sin API key, gratuito |
| Documentación de API | Swagger / OpenAPI | Generada automáticamente desde el código |
| Contenerización | Docker Compose | Un comando levanta API + base de datos con seed automático |

## El motor de decisiones, en una frase

Cruza 4 variables — evento climático activo, cultivo, etapa fenológica y tipo de suelo — contra un árbol de 180 combinaciones precargadas, y devuelve un nivel de riesgo más 3 acciones recomendadas. El contenido del árbol vive en un archivo JSON externo (`Scripts/reglas-preliminares-completas.json`), no hardcodeado en C#, para que se pueda actualizar sin recompilar el backend.

## Ver también

- [`security.md`](./security.md) — decisiones de seguridad y hallazgos resueltos.
- [`authentication.md`](./authentication.md) — flujo de login y JWT en detalle.
