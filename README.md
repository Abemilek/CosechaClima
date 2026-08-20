<p align="center">
  <img src="./docs/assets/cosechaclima-logo.svg" alt="CosechaClima" width="160">
</p>

<h1 align="center">CosechaClima</h1>
<p align="center"><strong>Sistema de alerta agroclimática temprana para pequeños productores de granos básicos en Carazo, Nicaragua.</strong></p>

Cruza datos climáticos en tiempo real contra un árbol de decisión agronómico para traducir el clima en tres acciones concretas que un productor puede tomar hoy — sin costo, sin conexión constante, sin depender de un técnico presente.

<p align="center">
  <img alt=".NET" src="https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet&logoColor=white">
  <img alt="SQL Server" src="https://img.shields.io/badge/SQL_Server-2022-CC2927?logo=microsoftsqlserver&logoColor=white">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
  <img alt="License" src="https://img.shields.io/badge/license-MIT-green">
  <img alt="Status" src="https://img.shields.io/badge/status-en%20desarrollo-yellow">
  <img alt="Cost" src="https://img.shields.io/badge/costo%20de%20infraestructura-%240-brightgreen">
  <br>
  <img alt="Build" src="https://img.shields.io/github/actions/workflow/status/Abemilek/CosechaClima/backend-ci.yml?branch=main">
  <img alt="Last Commit" src="https://img.shields.io/github/last-commit/Abemilek/CosechaClima">
  <img alt="Issues" src="https://img.shields.io/github/issues/Abemilek/CosechaClima">
  <img alt="Repo Size" src="https://img.shields.io/github/repo-size/Abemilek/CosechaClima">
</p>

---

## Tabla de contenido

- [El problema](#el-problema)
- [Cómo funciona](#cómo-funciona)
- [Arquitectura](#arquitectura)
- [Stack tecnológico](#stack-tecnológico)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Puesta en marcha](#puesta-en-marcha)
- [API — endpoints principales](#api--endpoints-principales)
- [Estado del proyecto](#estado-del-proyecto)
- [Seguridad](#seguridad)
- [Costo de infraestructura](#costo-de-infraestructura)
- [Cómo contribuir](#cómo-contribuir)
- [Roadmap](#roadmap)
- [Agradecimientos](#agradecimientos)
- [Licencia](#licencia)

---

## El problema

En Carazo, los granos básicos como maíz y frijol que ocupan el **62% del área agrícola del departamento**, muy por encima del café y otros cultivos permanentes. Los pequeños productores toman decisiones críticas de manejo —regar, drenar, proteger del viento— basándose en la observación directa del cielo, sin acceso a pronósticos localizados ni a un técnico agrónomo disponible todos los días.

CosechaClima traduce datos climáticos abiertos en una recomendación accionable de 3 pasos, adaptada al cultivo, la etapa fenológica y el tipo de suelo de cada parcela específica — pensado para funcionar en condiciones reales de conectividad intermitente y sin ningún costo de licenciamiento.

## Cómo funciona

1. El productor registra su parcela: cultivo, etapa fenológica (opcional — si no la fija, el sistema la calcula sola a partir de la fecha de siembra), tipo de suelo y coordenadas GPS.
2. Configura sus propios umbrales de riesgo (mm de lluvia, km/h de viento, días de canícula).
3. El sistema consulta datos climáticos reales de la zona vía Open-Meteo.
4. El **motor de decisiones** cruza evento climático × cultivo × etapa × suelo contra un árbol de **216 reglas agronómicas** (180 de eventos de riesgo + 36 de "sin riesgo") y calcula un semáforo de riesgo (🔴 Alto / 🟡 Medio / 🟢 Bajo / ⚪ Sin riesgo) con 3 acciones recomendadas.
5. El productor registra en su bitácora de campo qué acciones completó, y puede compartir un resumen de texto simple.

## Arquitectura

```
                         ┌──────────────────┐
                         │       App        │
                         └────────┬─────────┘
                                  │ 
                         ┌────────▼─────────┐
                         │   WebApi (API)   │ 
                         └────────┬─────────┘
                         ┌────────▼─────────┐
                         │ WebApi.Interface │  
                         └────────┬─────────┘
                         ┌────────▼──────────────┐
                         │ WebApi.Implementation  │
                         └────────┬───────────────┘
                    ┌─────────────┼──────────────────┐
            ┌───────▼──────┐  ┌───▼────────┐  ┌───────▼────────┐
            │  SQL Server  │  │ Open-Meteo │  │ WebApi.Models   │
            │  (Docker)    │  │  (clima)   │  │ (entidades)     │
            └──────────────┘  └────────────┘  └─────────────────┘
```

Arquitectura en capas estricta: cada capa solo conoce a la inmediatamente inferior a través de una interfaz — el motor de decisiones, por ejemplo, no sabe si los datos climáticos vienen de Open-Meteo, de NASA POWER, o de una base de datos local; solo conoce `IProveedorClimaticoService`.

## Stack tecnológico

| Capa | Tecnología | Por qué |
|---|---|---|
| Backend | ASP.NET Core (.NET 10) | LTS vigente, tipado fuerte, rendimiento |
| Base de datos | SQL Server 2022 (Docker) | Edición Developer, gratuita para uso no comercial |
| Acceso a datos | ADO.NET puro | Control total sobre las consultas, sin overhead de un ORM para el tamaño de este proyecto |
| Autenticación | JWT Bearer + PIN con hash PBKDF2 + salt | Sin dependencias externas de identidad |
| Datos climáticos | [Open-Meteo](https://open-meteo.com) | Pronóstico real hasta 16 días, sin API key, gratuito |
| Documentación de API | Swagger / OpenAPI | Generada automáticamente desde el código, con botón "Authorize" para JWT |
| Contenerización | Docker Compose | Un solo comando levanta API + base de datos con seed automático |
| Cliente móvil | Flutter | Desde una sola base de código |

## Estructura del repositorio

```
CosechaClima/
├── backend/
│   ├── WebApi/                    
│   ├── WebApi.Models/           
│   ├── Services/
│   │   ├── WebApi.Interface/        
│   │   └── WebApi.Implementation/   
│   ├── Scripts/                     
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── .env.example
├── mobile/                          
├── docs/                         
│   └── assets/             
└── README.md
```

## Ejecucion

Guía rápida — la referencia completa (incluyendo ejecución local sin Docker, variables opcionales, y solución de problemas) está en [`backend/README.md`](./backend/README.md).


## Seguridad

- Autenticación JWT con expiración configurable.
- PIN almacenado exclusivamente como hash PBKDF2 + salt individual por usuario — nunca en texto plano.
- Control de acceso por propietario (*ownership*) en todos los recursos: un usuario solo puede ver y modificar sus propias parcelas, umbrales y bitácoras.
- Rol `Admin` separado para operaciones administrativas (sembrar/aplicar reglas), otorgado por seed de configuración — nunca por un endpoint HTTP.
- Rate limiting en los endpoints de autenticación para mitigar fuerza bruta.
- Validación de entrada declarativa (DataAnnotations) y de existencia de claves foráneas en todos los endpoints de escritura.
- CORS restringido por lista explícita de orígenes permitidos (`Cors:AllowedOrigins`).
- Secretos gestionados por variables de entorno (`.env`, excluido de control de versiones); nunca hardcodeados en el código fuente.

Este proyecto pasó por varias rondas de revisión de seguridad alineadas al [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x00-header/) — el detalle de hallazgos y correcciones está documentado en `docs/`.

## Costo de infraestructura

**$0.** SQL Server Developer Edition, Open-Meteo, ASP.NET Core y todo el resto del stack son gratuitos para este caso de uso. El proyecto corre completo en una laptop vía Docker Compose, sin necesidad de ningún servicio pagado ni dominio, para efectos de demostración.

## Cómo contribuir

Este repositorio usa ramas de feature protegidas contra `main` y [Conventional Commits](https://www.conventionalcommits.org/):

```
tipo(alcance): descripción breve en presente
```

Convención de nombres de rama: `tipo/descripcion-corta` (ej. `fix/canicula-detection-connectivity-gaps`, `feat/add-catalog-endpoints`). Cada rama se mergea a `main` vía Pull Request.


## Agradecimientos

- [Open-Meteo](https://open-meteo.com) por el acceso gratuito a datos meteorológicos de alta resolución.
- INTA Nicaragua y FAO por las guías técnicas públicas de manejo de maíz y frijol usadas como base agronómica preliminar.
- [OWASP API Security Project](https://owasp.org/www-project-api-security/) como marco de referencia para el endurecimiento de seguridad de la API.

## Licencia

Este proyecto se distribuye bajo licencia MIT — ver [`LICENSE`](./LICENSE).

---