# Changelog

Todos los cambios notables de este proyecto se documentan en este archivo.
Formato basado en [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), versionado siguiendo [Semantic Versioning](https://semver.org/).

## [Unreleased] - Modo offline completo y flujo unificado de invitado

Motivado por pruebas en un teléfono real sin datos móviles: la app debía seguir
siendo útil (clima, parcelas y plan semanal) sin conexión, y el productor nuevo
no debía toparse con un login obligatorio para probarla.

### Added
- **Pronóstico público con caché**: `GET /api/clima/pronostico` se guarda en el teléfono (hasta 4 ubicaciones). Sin conexión o con el servidor caído, la pantalla "El clima de tu zona" muestra el último pronóstico descargado con un aviso visible, en vez de "No se pudo conectar con el servidor".
- **Catálogos con caché**: cultivos, tipos de suelo, etapas fenológicas y eventos climáticos quedan guardados tras la primera descarga; el registro de parcelas sigue funcionando sin internet.
- **Plan semanal invitado con caché**: el resumen de una parcela sin cuenta también se guarda para mostrarlo sin conexión.
- **Cola local de umbrales**: los umbrales configurados sin conexión (o durante el registro invitado) se suben solos al iniciar sesión / recuperar la conexión.

### Changed
- **Una sola pantalla de parcelas para invitado y cuenta**: "Mis parcelas" ya no exige iniciar sesión. Sin cuenta, muestra las parcelas guardadas en el teléfono con un aviso arriba ("Iniciá sesión para no perderlas"), sin bloquear el registro. Con cuenta, sube automáticamente lo que haya quedado local y lista todo junto.
- **Una sola pantalla para crear parcela**: el flujo de invitado (pantalla simplificada) se elimina; el mismo asistente de 5 pasos funciona con o sin cuenta. Sin GPS usa el centro del municipio (mismo criterio que el servidor).
- **Selector de municipio/departamento rediseñado** (antes: grid de 25 tarjetas que obligaba a hacer scroll buscando el tuyo): buscador con filtrado en vivo que ignora tildes, lista compacta agrupada con Carazo primero, el último municipio elegido se recuerda para el próximo registro y, al detectar el GPS, se preselecciona el departamento más cercano. Patrón oficial de Flutter para elegir entre muchas opciones (Autocomplete/RawAutocomplete).
- **Registro de parcela más corto**: el último paso ya no muestra 3 sliders, variedad, riego y horario SMS. Solo pide el área y deja las alertas con los valores recomendados; esa configuración se movió a "Ajustar mis alertas" dentro de la parcela (revelación progresiva: pedir solo lo necesario en el primer uso). Además, registrar una parcela ya no vuelve a guardar umbrales: se evita pisar los que el productor ya había personalizado (el servidor aplica los recomendados cuando no hay ninguno).
- **Pantalla de parcela simplificada**: de 4 pestañas a 3 (Inicio, Mi cuaderno, Semana). Se eliminó la pestaña "Alertas" que repetía el mismo riesgo y acciones que Inicio, y se quitaron los botones duplicados "Ver el detalle día por día" (ya es una pestaña) y "¿Cómo calculamos esto?" (ahora en el menú). Inicio tiene "tirar para actualizar".
- **Acciones con nombre en vez de iconos sueltos**: en "Mis parcelas" los tres iconos del encabezado (bitácora, umbrales, cerrar sesión) pasan a un solo menú "Más" con opciones escritas; "Umbrales" se renombra a **"Ajustar mis alertas"** en toda la app (lenguaje del productor, no técnico).
- **Accesibilidad** según las guías de Flutter/Android: área táctil mínima de 48 dp en las acciones de la bitácora, botón atrás nativo con etiqueta, y "tirar para actualizar" también en bitácora y lista de parcelas.
- **Tutorial actualizado**: hablaba de "3 acciones para hoy" y umbrales; ahora describe el semáforo de riesgo, el plan semanal y el cuaderno de campo, como funciona la app actual.
- **Crear parcela sin conexión estando logueado**: la parcela queda guardada en el teléfono y se sube a la cuenta sola cuando vuelva internet (antes se perdía con un error de red).

### Removed
- `GuestParcelaWizardScreen`: reemplazada por el asistente único `CrearParcelaWizardScreen` con `esInvitado`.

## [Unreleased] - Pruebas en dispositivo real: conectividad, catálogo de cultivos, plan semanal y modo invitado

Motivado por pruebas en un dispositivo real con `ngrok` como túnel de desarrollo.

### Fixed
- **Error crudo de ngrok en vez del modo sin conexión**: cuando el túnel de desarrollo (ngrok) está caído, devuelve una página de error HTML/texto con estado HTTP (no una falla de socket), y el cliente la mostraba tal cual ("ERR_NGROK_3200...") sin usar el respaldo con caché. Ahora `ApiClient` solo confía en respuestas que sean el JSON estructurado que nuestra propia API siempre devuelve; cualquier otra cosa (túnel caído, proxy, portal cautivo de wifi) se trata como problema de conectividad y activa el mismo respaldo con caché que ya funcionaba para desconexiones reales.
- **Solo se mostraban 2 cultivos al crear una parcela**: el selector estaba literalmente limitado con `cultivos.take(2)`, remanente de cuando solo existían Maíz y Frijol. Ya obtiene la lista completa del catálogo (ahora 5, y cualquier cultivo que un admin agregue después desde el panel).

### Added
- **Modo invitado**: un productor puede registrar una parcela y ver su plan semanal completo sin crear cuenta (patrón "probar antes de registrarte", como Duolingo). Se guarda localmente en el teléfono; un banner permanente pero no bloqueante invita a iniciar sesión "para no perder tus datos", y al hacerlo todas las parcelas guardadas localmente se suben automáticamente a la cuenta. Nuevo endpoint anónimo `POST /api/motor/resumen-semanal-anonimo` (sin persistir nada) para calcular el plan sin necesidad de una parcela guardada en la base de datos.
- La pantalla principal de una parcela ahora muestra **"Tu plan para esta semana"** (con el día más crítico señalado) en vez de "Tus 3 acciones de hoy": las acciones vienen del resumen semanal, no de una evaluación reactiva diaria, siguiendo la recomendación central de la auditoría técnica.

## [Unreleased] - Correcciones por auditoría técnica (profesor de psicología del producto + revisión propia)

Motivadas por dos rondas de retroalimentación: una auditoría en vivo con productores de Carazo (enfocada en escalabilidad y frecuencia de las alertas) y reportes propios de comportamiento fuera de línea.

### Added
- **Cobertura nacional**: `ZonaCobertura` pasa del bounding box de Carazo al bounding box real de Nicaragua (10.70–15.03 N, -87.70 a -82.70 O). `MunicipioCentroide` agrega los 15 departamentos + 2 regiones autónomas (cabecera departamental como referencia), sin perder el detalle fino de los 8 municipios de Carazo ya existentes. El selector de "municipio de respaldo sin GPS" en la app ahora cubre todo el país.
- **3 cultivos nuevos**: Arroz, Sorgo y Café, además de Maíz y Frijol — los granos básicos oficiales de Nicaragua (Banco Central / Plan Nacional de Producción) más el principal rubro de exportación. `SembrarReglasIniciales()` genera automáticamente las 90 combinaciones pendientes por cultivo nuevo; `reglas-preliminares-completas.json` suma 270 reglas preliminares (marcadas `PRELIMINAR`, pendientes de validación técnica real) con perfiles agronómicos diferenciados por cultivo (ej. el arroz tolera mal la sequía, el sorgo la tolera bien, el café es sensible a heladas en zonas altas).
- **Resumen semanal** (`GET /api/motor/resumen-semanal/{parcelaId}`): agrega el riesgo de los próximos 7 días del pronóstico en un solo boletín — con el día más crítico y hasta 3 acciones para toda la semana — en vez de una alerta reactiva por día. Nueva pestaña "Semana" en la app. Motivo: la práctica real de boletines agrometeorológicos (INETER/INTA) es semanal, no diaria; una alerta a las 9am pidiendo "ir a buscar agua ya" no le da tiempo útil al productor de programarse.
- **Modo sin conexión para la lista de parcelas**: si el servidor no responde o no hay internet, la app muestra la última lista de parcelas guardada en el dispositivo (con aviso "Sin conexión: mostrando datos guardados") en vez de una pantalla vacía con solo un error. La pantalla de detalle de parcela ya tenía este comportamiento; ahora la lista principal también.
- Endpoint `GET /api/catalogos/municipios` ahora devuelve los 17 departamentos/regiones en vez de los 8 municipios de Carazo.

### Changed
- Mensajes de la app ("Por ahora CosechaClima cubre la zona de Carazo", "fuera de Carazo", etc.) actualizados a alcance nacional.
- `README.md` / `README.es.md`: alcance actualizado de "Carazo" a "Nicaragua".

## [Unreleased]

### Added
- Inicio de sesion con **Google**: `POST /api/auth/google` valida el ID Token en el servidor (`Google.Apis.Auth`: firma, emisor, expiracion, audiencia y correo verificado). Si ya existe una cuenta de correo con el mismo email, las vincula.
- Registro y login con **correo + contrasena** (`POST /api/auth/register`, `POST /api/auth/login`). El registro devuelve el token directamente.
- **Modo invitado**: `GET /api/clima/pronostico` (publico, 5 dias por coordenadas, sin persistencia) y catalogos abiertos (`[AllowAnonymous]`). La app entra a un inicio publico y solo pide cuenta al acceder a lo privado.
- Esquema de `Usuarios` con `Email`, `GoogleUid`, `PasswordHash`, `PasswordSalt`, `Proveedor` y `FotoUrl`. La unicidad de `GoogleUid` es un indice unico filtrado (`WHERE GoogleUid IS NOT NULL`), porque una restriccion `UNIQUE` comun de SQL Server solo admite un `NULL` y bloquearia el segundo registro por correo.
- Script `Scripts/migracion-v2-auth.sql` para migrar bases existentes de telefono + PIN al esquema nuevo (con respaldo en `Usuarios_Respaldo_v1`).
- Variables `ADMIN_SEED_EMAIL`, `ADMIN_SEED_PASSWORD`, `GOOGLE_CLIENT_ID_ANDROID`, `GOOGLE_CLIENT_ID_IOS` y `GOOGLE_CLIENT_ID_WEB` (backend), y `GOOGLE_SERVER_CLIENT_ID` (app movil).
- Interfaces `ITokenGenerator` e `IGoogleTokenValidator`.
- App movil: pantallas `EmailAuthScreen`, `LoginSheet` (login contextual) y `PublicHomeScreen`; el onboarding se muestra una sola vez.
- Documentacion: [google-sign-in-setup.md](./google-sign-in-setup.md).

### Changed
- **BREAKING:** el identificador de cuenta pasa de `Telefono` a `Email`. `POST /api/auth/register` ya no devuelve `{ id, mensaje }` sino `LoginResponseDto` (`token`, `nombre`, `email`, `fotoUrl`, `esAdmin`), igual que `login` y `google`.
- **BREAKING:** el claim `MobilePhone` del JWT se reemplaza por `Email`.
- Las contrasenas se hashean con PBKDF2-HMAC-SHA256 (600.000 iteraciones, salt individual) en `HashPassword`.
- La politica de rate limiting `auth` (5/min por IP) ahora tambien cubre `POST /api/auth/google`.
- `CatalogoController` pasa de `[Authorize]` a `[AllowAnonymous]`; `ClimaController` sigue protegido salvo `GET /pronostico`.
- El admin inicial se define con `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` (antes telefono + PIN).
- `compose.yaml`: `ASPNETCORE_ENVIRONMENT` tiene por defecto `Production` (Swagger oculto y redireccion HTTPS activa); para desarrollo local se pisa desde `.env` con `Development`.
- La API valida `Jwt:SecretKey` al arrancar: falla si falta, es menor a 32 bytes o conserva el texto de relleno de `.env.example`.
- App movil: cuando expira la sesion se vuelve al modo publico en vez de forzar el login.

### Fixed
- `BD-CosechaClima.sql` es idempotente al recrear el indice `UK_ReglasDecision_Clave`: `OBJECT_ID` no reconoce indices, por lo que se intentaba recrearlo en cada `docker compose up`.

### Removed
- Login por telefono + PIN: `HashPin`, `LoginDto` anterior, columnas `Telefono`, `PinHash` y `PinSalt`, y en la app las pantallas de login/registro con PIN y el widget `PinInput`.

### Security
- Los ID Tokens de Google se validan siempre en el servidor; el backend nunca confia en el correo que declare la app.
- Cuentas de Google sin contrasena local: el login por correo responde el mismo `401` generico para no revelar que correos existen.
- Contrasenas de al menos 8 caracteres (OWASP / NIST SP 800-63B) en lugar de un PIN de 4 digitos.

### Pendiente
- Verificacion del correo al registrarse con contrasena (hoy la vinculacion con Google confia en que Google verifico el correo, pero el registro por correo no lo verifica).
- Rate limiting y cache para `GET /api/clima/pronostico` (hoy es publico y consulta Open-Meteo en cada llamada).
- Leer la IP real del cliente (`ForwardedHeaders`) cuando la API corra detras de un proxy o tunel; sin eso el rate limit por IP se comparte entre todos los usuarios.
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