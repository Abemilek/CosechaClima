# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.
Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versionado siguiendo [Semantic Versioning](https://semver.org/).

## [Unreleased]

### Pendiente
- Validacion tecnica formal del arbol de reglas completo (INTA/MARENA).
- Alertas proactivas usando el pronostico multi-dia de Open-Meteo (no solo el dia actual).
- Reportes comunitarios geolocalizados (fase 2).
- Notificaciones SMS.
- Versionado de API (`/api/v1/...`).

## [1.1.0]

### Added
- Dockerfile multi-stage usando `aspnet:10.0-alpine` como runtime para superficie de ataque minima e imagen reducida.
- `compose.yaml` en la raiz del proyecto (estandar moderno de Docker Compose) reemplazando el legacy `docker-compose.yml` en `/backend`.
- `.env.example` en la raiz con descripciones documentadas de cada variable de entorno y reglas de validacion.
- Pipeline CI con GitHub Actions (`backend-ci.yml`) incluyendo pasos `dotnet build` y `dotnet test`.
- Politica de Rate Limiting `motor` en `MotorDecisionesController` para prevenir abuso del motor de decisiones computacionalmente intensivo.
- Claim `Jti` (JWT ID) en la generacion de tokens para unicidad y soporte futuro de revocacion.
- Parseo JSON en segundo plano en Flutter usando `compute` / Isolates para payloads pesados (`BitacoraService`).
- Inyeccion de entorno via `--dart-define` en Flutter, eliminando URLs de API hardcodeadas del codigo fuente.

### Changed
- Registro DI de `ConnectionBD` cambiado de `AddScoped` a `AddSingleton` -- es una fabrica de conexiones que crea nuevas instancias de `SqlConnection` por llamada, no una conexion compartida. Singleton evita re-instanciacion innecesaria.
- `ReglaDecisionService.AplicarContenidoPreliminar` refactorizado de N+1 UPDATEs individuales a un unico batch T-SQL usando `OPENJSON`, mejorando dramaticamente el rendimiento.
- Motor de decisiones (`MotorDecisionesService.DetermineActiveEvent`) refactorizado de if/return secuencial (evento unico) a `DetermineActiveEvents` (eventos concurrentes multiples). Ahora recolecta TODOS los eventos climaticos activos, evalua reglas para cada uno, y retorna el riesgo de mayor prioridad. Elimina el conditional shadowing donde eventos severos eran silenciados por comprobaciones anteriores.
- Consumo de estado en Flutter refactorizado de `context.watch<ViewModel>()` a nivel raiz a uso granular de `Selector`/`Consumer`, previniendo rebuilds innecesarios del arbol completo de widgets.
- Navegacion de paginas en Flutter cambiada de `animateToPage` a `jumpToPage` (politica Cero Animaciones).
- Validacion de clave secreta JWT reforzada a minimo 32 caracteres (256 bits) para cumplimiento HMAC-SHA256.
- Archivo compose renombrado de `docker-compose.yml` a `compose.yaml` segun estandar moderno de Docker y movido a la raiz del proyecto.
- Imagen runtime del Dockerfile cambiada de Debian estandar a Alpine para tamano reducido y menor superficie de vulnerabilidades.

### Fixed
- Comparacion de hash de PIN actualizada a `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.
- Widgets `AnimatedContainer` en Flutter reemplazados con `Container` estatico (cumplimiento Cero Animaciones).
- Apariciones animadas de `CircularProgressIndicator` reemplazadas con estados de carga estaticos.
- Incompatibilidad de tipos `decimal` vs `double` en `DetermineActiveEvents` -- propiedades del modelo climatico son `decimal?`, comparaciones ahora usan literales `decimal` (`2m`, `35m`) en lugar de `double`.
- Warning de referencia nullable (`CS8600`) corregido: `ReglaDecision reglaPrioritaria` declarado como `ReglaDecision?`.

### Security
- Alineacion completa con OWASP API Security Top 10 (edicion 2023).
- Claim JWT `Jti` previene reutilizacion de tokens en escenarios de replay attack.
- Rate Limiting en motor de decisiones previene ataques de agotamiento de recursos.
- Runtime Docker Alpine elimina CVEs conocidos presentes en imagenes Debian estandar.
- Ejecucion con usuario no-root en contenedor Docker.
- Manejador global de errores (`ManejadorErroresGlobal`) asegura que detalles internos de excepciones nunca se expongan a clientes.
- Prevencion de inyeccion SQL verificada: todas las queries usan comandos parametrizados exclusivamente.

## [1.0.0]

Release inicial -- Funcionalidad central y endurecimiento de seguridad.

### Added
- Autenticacion por telefono + PIN con tokens JWT Bearer.
- CRUD para Parcelas, Umbrales y Bitacora de campo.
- Motor de decisiones: cruza evento climatico x cultivo x etapa fenologica x tipo de suelo contra arbol de 216 reglas agronomicas.
- Catalogo base: Maiz, Frijol, 6 etapas fenologicas, 3 tipos de suelo, 6 eventos climaticos.
- Arbol de decision completo: 216 reglas (180 eventos de riesgo + 36 sin riesgo) con contenido agronomico preliminar.
- Contenido de reglas externalizado a `Scripts/reglas-preliminares-completas.json`.
- Rol `Admin` para endpoints de `ReglaDecisionController`.
- `[Authorize]` en todos los controladores de negocio.
- Verificacion de ownership via claims JWT en Parcelas, Bitacora, Umbrales, Clima y Motor.
- DTOs de request dedicados con validacion declarativa.
- Manejador global de excepciones (`IExceptionHandler` + `ProblemDetails`).
- Rate limiting (ventana deslizante) en `/api/auth/register` y `/api/auth/login`.
- Health check en `/health`.
- Docker Compose con bootstrap automatico de esquema y seeding de catalogos.
- Deteccion de canicula multi-dia.
- Evento climatico "Sin riesgo" para caso donde ningun umbral se supera.
- Migracion de proveedor climatico de NASA POWER a Open-Meteo.
- Logica de sembrado de reglas movida de scripts SQL a `ReglaDecisionService` (C#).

### Fixed
- Rango de validacion de `AreaMzs` alineado con precision de columna en BD (`DECIMAL(7,2)`).
- Errores SQL de violacion FK (547) y constraint unico (2601/2627) traducidos a 400/409 en lugar de 500 generico.
- Bug de binding de rutas en `BitacoraController` -- parametros de metodo no coincidian con placeholders de ruta.

### Security
- Revision OWASP API Security Top 10 (2023) completada; hallazgos documentados en `security.md`.
