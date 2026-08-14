# Changelog

Todos los cambios notables de la API se documentan en este archivo. Formato basado en [Keep a Changelog](https://keepachangelog.com/es-ES/1.1.0/).

## [Unreleased]

### Pendiente
- Validación técnica formal del árbol de reglas completo (INTA/MARENA).
- Alertas proactivas usando el pronóstico a futuro de Open-Meteo (no solo el día actual).
- Reportes comunitarios geolocalizados (fase 2).
- Notificaciones SMS.
- Cobertura de pruebas automatizadas más amplia.
- Rate limiting por IP (actualmente es global por servidor).
- Versionado de API (`/api/v1/...`).

## Contenido y roles

### Added
- Árbol de decisión completo: 180 reglas con contenido preliminar generado sistemáticamente.
- Contenido del árbol de reglas externalizado a `Scripts/reglas-preliminares-completas.json`, desacoplado del código fuente.
- Rol `Admin` para endpoints administrativos de `ReglaDecisionController` (antes protegidos solo con `[Authorize]` genérico).

### Fixed
- `AreaMzs`: rango de validación del DTO alineado con la precisión real de la columna en base de datos (`DECIMAL(7,2)`).
- Errores de violación de clave foránea (`SqlException 547`) y de duplicados (`2601`/`2627`) ahora se traducen a `400`/`409` claros en vez de `500` genérico.
- Comparación del hash del PIN migrada a tiempo constante (`CryptographicOperations.FixedTimeEquals`), mitigando timing attacks.

## Endurecimiento de seguridad

### Added
- `[Authorize]` en todos los controladores de negocio.
- Verificación de ownership por claims de JWT en Parcelas, Bitácora, Umbrales, Clima y Motor de Decisiones.
- DTOs de request dedicados (`ParcelaRequestDto`, `BitacoraRequestDto`, `UmbralRequestDto`) con validación declarativa, reemplazando el binding directo de entidades de dominio.
- Manejo global de excepciones (`IExceptionHandler` + `ProblemDetails`).
- Rate limiting (ventana deslizante) en `/api/auth/register` y `/api/auth/login`.
- Health check en `/health`.

### Fixed
- Bug de binding de rutas en `BitacoraController` — los parámetros de método no coincidían con los placeholders de la ruta, dejando 3 de 4 endpoints no funcionales.

### Security
- Revisión alineada al OWASP API Security Top 10 (2023); ver [`security.md`](./security.md).

## Proveedor climático y automatización

### Changed
- Migración del proveedor de datos climáticos de NASA POWER a Open-Meteo (mayor resolución, pronóstico real en vez de solo datos históricos).
- Lógica de sembrado del árbol de reglas movida de scripts SQL sueltos a `ReglaDecisionService` (C#), invocable vía endpoint.

### Added
- Docker Compose con bootstrap automático de esquema y catálogos.
- Detección de canícula multi-día (antes evaluaba un solo día).
- Evento climático "Sin riesgo" para el caso donde ningún umbral se supera.

## Núcleo funcional

### Added
- Autenticación por teléfono + PIN, JWT.
- CRUD de Parcelas, Umbrales, Bitácora de campo.
- Motor de decisiones: cruce de evento climático × cultivo × etapa fenológica × tipo de suelo contra árbol de reglas.
- Catálogo base: Maíz y Frijol, 6 etapas fenológicas, 3 tipos de suelo, 6 eventos climáticos.
