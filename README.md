# CosechaClima

**Sistema de alerta agroclimática temprana para pequeños productores de granos básicos en Carazo, Nicaragua.**

Cruza datos climáticos en tiempo real contra un árbol de decisión agronómico para traducir el clima en tres acciones concretas que un productor puede tomar hoy — sin costo, sin conexión constante, sin depender de un técnico presente.

<p align="left">
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

En Carazo, los granos básicos (maíz y frijol) ocupan el **62% del área agrícola del departamento**, muy por encima del café y otros cultivos permanentes. Los pequeños productores toman decisiones críticas de manejo —regar, drenar, proteger del viento— basándose en la observación directa del cielo, sin acceso a pronósticos localizados ni a un técnico agrónomo disponible todos los días.

CosechaClima traduce datos climáticos abiertos en una recomendación accionable de 3 pasos, adaptada al cultivo, la etapa fenológica y el tipo de suelo de cada parcela específica — pensado para funcionar en condiciones reales de conectividad intermitente y sin ningún costo de licenciamiento.

## Cómo funciona

1. El productor registra su parcela: cultivo, etapa fenológica, tipo de suelo y coordenadas GPS.
2. Configura sus propios umbrales de riesgo (mm de lluvia, km/h de viento, días de canícula).
3. El sistema consulta datos climáticos reales de la zona.
4. El **motor de decisiones** cruza evento climático × cultivo × etapa × suelo contra un árbol de **180 reglas agronómicas** y calcula un semáforo de riesgo (🔴 Alto / 🟡 Medio / 🟢 Bajo / ⚪ Sin riesgo) con 3 acciones recomendadas.
5. El productor registra en su bitácora de campo qué acciones completó, y puede compartir un resumen de texto simple.

## Arquitectura

```
                         ┌──────────────────┐
                         │   App Flutter    │  (cliente móvil)
                         └────────┬─────────┘
                                  │ HTTPS + JWT
                         ┌────────▼─────────┐
                         │   WebApi (API)   │  Controllers, DTOs, autenticación
                         └────────┬─────────┘
                         ┌────────▼─────────┐
                         │ WebApi.Interface │  Contratos
                         └────────┬─────────┘
                         ┌────────▼──────────────┐
                         │ WebApi.Implementation  │  Lógica de negocio + ADO.NET
                         └────────┬───────────────┘
                    ┌─────────────┼──────────────────┐
            ┌───────▼──────┐  ┌───▼────────┐  ┌───────▼────────┐
            │  SQL Server  │  │ Open-Meteo │  │ WebApi.Models   │
            │  (Docker)    │  │  (clima)   │  │ (entidades)     │
            └──────────────┘  └────────────┘  └─────────────────┘
```

Arquitectura en capas estricta: cada capa solo conoce a la inmediatamente inferior a través de una interfaz — el motor de decisiones, por ejemplo, no sabe si los datos climáticos vienen de Open-Meteo, de NASA POWER, o de una base de datos local; solo conoce `IProveedorClimaticoService`. Esto permitió migrar el proveedor climático completo sin tocar ninguna otra capa del sistema.

## Stack tecnológico

| Capa | Tecnología | Por qué |
|---|---|---|
| Backend | ASP.NET Core (.NET 10) | LTS vigente, tipado fuerte, rendimiento |
| Base de datos | SQL Server 2022 (Docker) | Edición Developer, gratuita para uso no comercial |
| Acceso a datos | ADO.NET puro | Control total sobre las consultas, sin overhead de un ORM para el tamaño de este proyecto |
| Autenticación | JWT Bearer + PIN con hash SHA-256 + salt | Sin dependencias externas de identidad |
| Datos climáticos | [Open-Meteo](https://open-meteo.com) | Pronóstico real hasta 16 días, sin API key, gratuito |
| Documentación de API | Swagger / OpenAPI | Generada automáticamente desde el código |
| Contenerización | Docker Compose | Un solo comando levanta API + base de datos con seed automático |
| Cliente móvil | Flutter | Desde una sola base de código |

## Estructura del repositorio

```
CosechaClima/
├── backend/
│   ├── WebApi/                      # Controladores, DTOs, Program.cs
│   ├── WebApi.Models/                # Entidades de dominio
│   ├── Services/
│   │   ├── WebApi.Interface/         # Contratos de servicio
│   │   └── WebApi.Implementation/    # Lógica de negocio + acceso a datos
│   ├── Scripts/                      # Esquema SQL y catálogos (seed)
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── .env.example
├── mobile/                           # App Flutter
├── docs/                             # Documentación técnica y análisis
└── README.md
```

## Puesta en marcha

### Requisitos
- Docker y Docker Compose
- (Opcional, para desarrollo sin contenedores) SDK de .NET 10

### Levantar todo con Docker Compose

```bash
git clone https://github.com/Abemilek/CosechaClima.git
cd CosechaClima/backend
cp .env.example .env
# Editar .env con tus propios valores (contraseña de DB, clave JWT)
docker compose up --build
```

Esto levanta la base de datos, aplica el esquema y los catálogos automáticamente, y expone la API en `http://localhost:8080/swagger`.

### Primeros pasos con la API

```bash
# 1. Sembrar el árbol de reglas de decisión
curl -X POST http://localhost:8080/api/reglas/sembrar
curl -X POST http://localhost:8080/api/reglas/aplicar-contenido-preliminar

# 2. Registrar un usuario
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Juan Perez","telefono":"88887777","pin":"1234"}'

# 3. Iniciar sesion
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"telefono":"88887777","pin":"1234"}'
```

## API — endpoints principales

| Método | Ruta | Descripción | Requiere token |
|---|---|---|---|
| `POST` | `/api/auth/register` | Registro de productor | No |
| `POST` | `/api/auth/login` | Inicio de sesión, devuelve JWT | No |
| `POST` | `/api/parcelas` | Registrar una parcela | Sí |
| `GET` | `/api/parcelas/mias` | Listar parcelas del usuario autenticado | Sí |
| `POST` | `/api/umbrales` | Configurar umbrales de riesgo | Sí |
| `POST` | `/api/clima/actualizar/{parcelaId}` | Traer clima real de Open-Meteo | Sí |
| `GET` | `/api/motor/semaforo?parcelaId=` | Calcular el semáforo de riesgo | Sí |
| `POST` | `/api/logs` | Registrar entrada de bitácora | Sí |
| `GET` | `/api/logs/mias` | Historial de bitácora del usuario | Sí |
| `GET` | `/health` | Estado de salud de la API y la base de datos | No |

Documentación completa e interactiva disponible en `/swagger` una vez levantado el proyecto.

## Estado del proyecto

| Módulo | Estado |
|---|---|
| Modelo de datos y catálogos (Maíz, Frijol) | ✅ Completo |
| Motor de decisiones (semáforo, canícula multi-día) | ✅ Completo |
| Reglas de decisión — estructura (180 combinaciones) | ✅ Completo |
| Reglas de decisión — contenido validado técnicamente | 🟡 5 de 180 (preliminar, pendiente de validación INTA) |
| Autenticación (PIN + JWT) | ✅ Completo |
| Autorización y control de acceso por usuario | ✅ Completo |
| Proveedor climático con pronóstico (Open-Meteo) | ✅ Completo |
| Manejo global de errores y rate limiting | ✅ Completo |
| Pruebas automatizadas | 🟡 Cobertura mínima (motor de decisiones + auth) |
| Reportes comunitarios | ⬜ Planeado (fase 2) |
| Notificaciones por SMS | ⬜ Planeado (capa móvil) |
| CI/CD | 🟡 Compilación automática en cada push/PR (`backend-ci.yml`) |

## Seguridad

- Autenticación JWT con expiración configurable.
- PIN almacenado exclusivamente como hash SHA-256 + salt individual por usuario — nunca en texto plano.
- Control de acceso por propietario (*ownership*) en todos los recursos: un usuario solo puede ver y modificar sus propias parcelas, umbrales y bitácoras.
- Rate limiting en los endpoints de autenticación para mitigar fuerza bruta.
- Validación de entrada declarativa (DataAnnotations) en todos los endpoints de escritura.
- Secretos gestionados por variables de entorno (`.env`, excluido de control de versiones); nunca hardcodeados en el código fuente.

Este proyecto pasó por una revisión de seguridad interna alineada al [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x00-header/) — el detalle de hallazgos y correcciones está documentado en `docs/`.

## Costo de infraestructura

**$0.** SQL Server Developer Edition, Open-Meteo, ASP.NET Core y todo el resto del stack son gratuitos para este caso de uso. El proyecto corre completo en una laptop vía Docker Compose, sin necesidad de ningún servicio pagado ni dominio, para efectos de demostración.

## Cómo contribuir

Este repositorio usa ramas de feature protegidas contra `main` y [Conventional Commits](https://www.conventionalcommits.org/):

```
tipo(alcance): descripción breve en presente

feat(parcelas): add ownership validation to update endpoint
fix(bitacora): correct route parameter binding
docs: update API endpoint table
test(motor): add unit tests for canicula detection
chore(docker): add healthcheck to api service
```

Convención de nombres de rama: `tipo/descripcion-corta` (ej. `fix/authorization-and-route-binding`, `feat/error-handling-rate-limiting-health`). Cada rama se mergea a `main` vía Pull Request.

## Roadmap

- [ ] Validación técnica del árbol de reglas completo con INTA/MARENA.
- [ ] Alertas proactivas usando el pronóstico a futuro de Open-Meteo (no solo el día actual).
- [ ] Reportes comunitarios geolocalizados (fase 2, según diseño original).
- [ ] Notificaciones SMS para zonas sin datos móviles.
- [x] Compilación automática en cada push/PR (`.github/workflows/backend-ci.yml`).
- [ ] Agregar el paso `dotnet test` al CI existente, para que las pruebas del README 16 corran automáticamente.

## Agradecimientos

- [Open-Meteo](https://open-meteo.com) por el acceso gratuito a datos meteorológicos de alta resolución.
- INTA Nicaragua y FAO por las guías técnicas públicas de manejo de maíz y frijol usadas como base agronómica preliminar.
- [OWASP API Security Project](https://owasp.org/www-project-api-security/) como marco de referencia para el endurecimiento de seguridad de la API.

## Licencia

Este proyecto se distribuye bajo licencia MIT — ver [`LICENSE`](./LICENSE).

---

<p align="center">Hecho para los productores de Carazo, Nicaragua 🇳🇮</p>