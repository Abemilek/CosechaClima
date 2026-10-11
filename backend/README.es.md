# CosechaClima -- Backend

<!-- README-I18N:START -->

[English](./README.md) | **Español**

<!-- README-I18N:END -->

API REST para CosechaClima, un sistema de alerta temprana climatica para pequenos productores de maiz y frijol en Carazo, Nicaragua. ASP.NET Core 10, PostgreSQL 2022, ADO.NET.

---

## Tabla de contenidos

- [Arquitectura](#arquitectura)
- [Stack tecnico](#stack-tecnico)
- [Requisitos previos](#requisitos-previos)
- [Opcion A -- Ejecutar con Docker](#opcion-a----ejecutar-con-docker)
- [Opcion B -- Ejecutar localmente sin Docker](#opcion-b----ejecutar-localmente-sin-docker)
- [Variables de configuracion](#variables-de-configuracion)
- [Usuario administrador](#usuario-administrador)
- [Migracion de esquema: de telefono + PIN a correo + Google](#migracion-de-esquema-de-telefono--pin-a-correo--google)
- [Despliegue con Docker -- Dockerfile multi-stage](#despliegue-con-docker----dockerfile-multi-stage)
- [Patrones de arquitectura y seguridad](#patrones-de-arquitectura-y-seguridad)
- [Endpoints disponibles](#endpoints-disponibles)
- [Comandos utiles](#comandos-utiles)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Problemas comunes](#problemas-comunes)

---

## Arquitectura

```
CosechaClima.sln
|-- WebApi/                    # Capa de presentacion HTTP
|   |-- Controllers/
|   |-- Dto/
|   |-- ManejadorErroresGlobal.cs
|   |-- Program.cs
|-- WebApi.Models/             # Entidades de dominio
|-- Services/
|   |-- WebApi.Interface/      # Contratos de servicio
|   |-- WebApi.Implementation/ # Logica de negocio + Npgsql (SQL puro)
|       |-- Connection/        # ConnectionBD (NpgsqlDataSource), MigradorBD
|       |-- Security/          # HashPassword, TokenGenerator, GoogleTokenValidator
|       |-- Exceptions/        # RecursoNoEncontradoException, FlujoIncompletoException
|-- Scripts/
|   |-- migrations/            # 001_esquema_inicial.sql, 002_catalogos_base.sql, ...
|   |-- db-init/01-roles.sh    # crea el rol de la app (solo 1.a vez del volumen)
|   |-- reglas-preliminares-completas.json
|-- Dockerfile
```

## Stack tecnico

| Componente | Tecnologia |
|---|---|
| Framework | ASP.NET Core 10 (.NET 10) |
| Base de datos | PostgreSQL 18 |
| Acceso a datos | Npgsql 10 (`NpgsqlDataSource`) con SQL explicito, upserts `INSERT ... ON CONFLICT` y `jsonb_to_recordset` para operaciones batch |
| Autenticacion | JWT Bearer (correo + contrasena con hash PBKDF2 + salt, o Google Sign-In validado con `Google.Apis.Auth`; claim `Jti`) |
| Datos climaticos | Open-Meteo (API publica, sin key) |
| Documentacion de API | Swagger / OpenAPI |
| Contenedores | Docker multi-stage build (SDK -> Alpine runtime) |
| Manejo de errores | RFC 7807 ProblemDetails via `ManejadorErroresGlobal` |

## Requisitos previos

- [.NET SDK 10](https://dotnet.microsoft.com/download) (si no usaras Docker)
- [Docker + Docker Compose](https://www.docker.com/) (recomendado)
- Un cliente de PostgreSQL para inspeccion (`psql`, DBeaver, pgAdmin o la extension de VS Code)

## Opcion A -- Ejecutar con Docker

> [!NOTE]
> El archivo `compose.yaml` esta en la **raiz del proyecto** (no dentro de `/backend`). Todas las variables se leen del `.env` de la raiz.

```bash
cd CosechaClima   # raiz del proyecto
cp .env.example .env
# Editar .env -- ver comentarios en .env.example
docker compose up --build -d
```

> [!WARNING]
> `DB_APP_PASSWORD` debe ser **exactamente la misma** contrasena que escribas dentro de `CONNECTION_STRING`. `DB_ADMIN_PASSWORD` es la del superusuario `postgres`, reservado para administracion; la API nunca lo usa.

Los contenedores se inician en orden: **db** (PostgreSQL 18; la primera vez crea el rol `cosechaclima_app`, sin privilegios de superusuario, y su base) -> **api** (http://localhost:8080), que al arrancar aplica las migraciones SQL de `Scripts/migrations` antes de atender peticiones.

> [!WARNING]
> PostgreSQL solo aplica las contrasenas **la primera vez** que inicializa el volumen `cosechaclima-db-data`. Para cambiarlas despues usa `ALTER ROLE cosechaclima_app PASSWORD '...'`. En desarrollo, para empezar limpio: `docker compose down -v && docker compose up --build` (**borra los datos**).

> [!NOTE]
> La imagen `postgres:18` espera el volumen en `/var/lib/postgresql` (no en `/var/lib/postgresql/data` como en la 17 y anteriores); `compose.yaml` ya lo hace asi.

Verificacion:

```bash
curl http://localhost:8080/health
```

Esperado: `200 OK` con `Healthy`.

## Opcion B -- Ejecutar localmente sin Docker

### 1. Levantar solo PostgreSQL

```bash
docker run -d --name cosechaclima-db-local \
  -e POSTGRES_PASSWORD=postgres_admin_local \
  -p 127.0.0.1:5432:5432 \
  -v cosechaclima-local:/var/lib/postgresql \
  postgres:18

docker exec -i cosechaclima-db-local psql -U postgres <<'SQL'
CREATE ROLE cosechaclima_app LOGIN PASSWORD 'app_local_pw' NOSUPERUSER;
CREATE DATABASE cosechaclima OWNER cosechaclima_app;
SQL
```

### 2. Configurar la API

```bash
cd backend/WebApi
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:BD_CosechaClima" "Host=localhost;Port=5432;Database=cosechaclima;Username=cosechaclima_app;Password=app_local_pw"
dotnet user-secrets set "Jwt:SecretKey" "una-clave-larga-de-al-menos-32-caracteres-para-hmac-sha256"
# Opcional: Google Sign-In (ver docs/google-sign-in-setup.md)
dotnet user-secrets set "GoogleAuth:ClientIds:0" "<client id web>.apps.googleusercontent.com"
```

### 3. Correr la API

```bash
cd backend/WebApi
dotnet run
```

Arranca en `http://localhost:5013` (perfil http). El esquema y los catalogos se crean solos (migraciones).

## Variables de configuracion

| Clave | Docker (`.env`) | Local (user-secrets) | Requerida |
|---|---|---|---|
| `ConnectionStrings:BD_CosechaClima` | `CONNECTION_STRING` | Si | Si (formato Npgsql: `Host=...;Port=...;Database=...;Username=...;Password=...`) |
| `Jwt:SecretKey` | `JWT_SECRET_KEY` | Si | Si (minimo 32 caracteres para HMAC-SHA256) |
| `Jwt:Issuer` | `JWT_ISSUER` | Tiene default | No |
| `Jwt:Audience` | `JWT_AUDIENCE` | Tiene default | No |
| `Jwt:DurationMinutes` | `JWT_DURATION_MINUTES` | Tiene default (15) | No (la API avisa si es mayor a 60) |
| `Jwt:RefreshDays` | `JWT_REFRESH_DAYS` | Tiene default (30) | No (deslizante; tope absoluto de 180 dias por inicio de sesion) |
| `Auth:CookieSecure` | `AUTH_COOKIE_SECURE` | Tiene default (true) | No (ponla en `false` solo para probar el Admin Console por http://localhost sin TLS) |
| `Proxy:KnownProxies:0` | `PROXY_KNOWN_PROXY` | No | No (IP de tu proxy inverso) |
| `Proxy:KnownNetworks:0` | `PROXY_KNOWN_NETWORK` | No | No (CIDR de la red de tu proxy) |
| `AdminSeed:Email` | `ADMIN_SEED_EMAIL` | Si | No (correo valido) |
| `AdminSeed:Password` | `ADMIN_SEED_PASSWORD` | Si | No (minimo 8 caracteres) |
| `AdminSeed:Nombre` | `ADMIN_SEED_NOMBRE` | Si | No |
| `GoogleAuth:ClientIds:0` | `GOOGLE_CLIENT_ID_ANDROID` | Si | No (necesaria para Google Sign-In) |
| `GoogleAuth:ClientIds:1` | `GOOGLE_CLIENT_ID_IOS` | Si | No |
| `GoogleAuth:ClientIds:2` | `GOOGLE_CLIENT_ID_WEB` | Si | Si para Google Sign-In: es el `aud` del token que Google emite a la app |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | Si | No |
| `ASPNETCORE_ENVIRONMENT` | `ASPNETCORE_ENVIRONMENT` | Si | No (default `Production`: Swagger oculto; `Development` lo habilita) |

Los Client IDs vacios se ignoran. Si no hay ninguno, `POST /api/auth/google` responde `401` y el log de la API dice `GoogleAuth:ClientIds no esta configurado`. Las cuentas por correo funcionan igual.

**Detras de un proxy:** declaralo con `Proxy:KnownProxies` / `Proxy:KnownNetworks`. Sin eso se ignoran las cabeceras `X-Forwarded-*` (nadie puede falsear su IP) y el rate limiting por IP veria solo la direccion del proxy.

## Usuario administrador

**Automatico (recomendado):** completa `ADMIN_SEED_EMAIL` y `ADMIN_SEED_PASSWORD` (y opcionalmente `ADMIN_SEED_NOMBRE`) en el `.env`. El correo debe ser valido y la contrasena de al menos 8 caracteres, si no el seed se omite con una advertencia. Al arrancar, si el usuario no existe se crea con rol Admin; si existe pero no es Admin, se le otorga el rol.

**Manual:** registra un usuario normal via `POST /api/auth/register` (o entra con Google) y luego:

```sql
UPDATE usuarios SET es_admin = true WHERE email = '<correo en minusculas>';
```

No hay endpoint HTTP para auto-promoverse a admin -- es una decision de diseno intencional. El usuario debe volver a iniciar sesion tras el cambio.

## Base de datos y migraciones

El esquema vive en archivos SQL planos: `Scripts/migrations/001_*.sql`, `002_*.sql`, ... Al arrancar, `MigradorBD` aplica los pendientes en orden, cada uno dentro de una transaccion, bajo un advisory lock de PostgreSQL (dos instancias de la API no migran a la vez), y registra version + checksum en `schema_migrations`.

- **Nunca edites una migracion ya aplicada**: se verifica su checksum y la API no arranca si cambio. Crea un archivo nuevo (`004_...sql`).
- Los motivos de PostgreSQL, SQL puro en vez de ORM, las convenciones y el camino de migracion desde la antigua base SQL Server estan en [docs/postgresql.md](../docs/postgresql.md).

## Despliegue con Docker -- Dockerfile multi-stage

El Dockerfile utiliza un build multi-stage:

- **Stage 1 (build):** `mcr.microsoft.com/dotnet/sdk:10.0` -- restaura dependencias y publica la aplicacion.
- **Stage 2 (runtime):** `mcr.microsoft.com/dotnet/aspnet:10.0-alpine` -- imagen minima Alpine.
  - Ejecucion con usuario no-root.
  - Superficie de ataque minima (sin utilidades de shell innecesarias).
  - Tamano de imagen drasticamente reducido comparado con imagenes Debian estandar.

> [!NOTE]
> El healthcheck en `compose.yaml` usa `wget --spider -q http://localhost:8080/health` porque Alpine no incluye `curl` por defecto.

## Patrones de arquitectura y seguridad

### Inyeccion de dependencias

- `ConnectionBD` registrado como `AddSingleton` -- envuelve un unico `NpgsqlDataSource` (el pool de conexiones, thread-safe por diseno) y entrega una conexion nueva por llamada que vuelve al pool al liberarse.
- Todos los servicios de negocio registrados como `AddScoped`.

### Practicas de acceso a datos

- Queries parametrizadas exclusivamente (cero concatenacion de strings en SQL).
- `jsonb_to_recordset` para el batch de `ReglaDecisionService.AplicarContenidoPreliminar` (un UPDATE en vez de N+1); por defecto solo rellena reglas aun `PENDIENTE`, asi ya no pisa lo que un admin edito.
- Upserts con `INSERT ... ON CONFLICT DO UPDATE` (umbrales, alertas, clima) en lugar de leer y luego escribir: atomico bajo concurrencia.
- Las 540 reglas activas se cachean en memoria (`IMemoryCache`) y se invalidan cuando un admin las edita; antes cada busqueda abria una conexion.
- `ORDER BY` explicito en toda lista: PostgreSQL no garantiza orden sin el.
- Todas las conexiones envueltas en bloques `using` asegurando liberacion determinista.

### Rate Limiting

| Politica | Ventana | Limite | Endpoints |
|---|---|---|---|
| `auth` | Deslizante, 1 minuto | 5 peticiones por IP | `/api/auth/register`, `/api/auth/login`, `/api/auth/google`, `/api/auth/web/login` |
| `refresh` | Deslizante, 1 minuto | 30 peticiones por IP | `/api/auth/refresh`, `/api/auth/logout`, `/api/auth/web/refresh` |
| `publico` | Deslizante, 1 minuto | 30 peticiones por IP | `GET /api/reglas/paquete` |
| `motor` | Aplicada al controlador | Previene abuso | `/api/motor/semaforo` |

> [!WARNING]
> Las politicas por IP cuentan por la IP de origen de la conexion. Detras de un proxy declaralo en `Proxy:KnownProxies` / `Proxy:KnownNetworks` para leer la IP real desde `X-Forwarded-For`; si no, el limite pasa a ser global. Ver [docs/security.md](../docs/security.md).

### Seguridad JWT

- Firmado con HMAC-SHA256, clave secreta minimo 32 caracteres.
- Claim `Jti` (JWT ID) para unicidad de token y prevencion de replay attacks.
- Access token de vida corta (default **15 minutos**, 30 s de tolerancia de reloj) mas un **refresh token** opaco de un solo uso (se guarda su SHA-256, rota en cada uso y se revoca la familia si se reutiliza; 30 dias deslizante, 180 absoluto). Admin Console: refresh token en una cookie `HttpOnly` `SameSite=Strict`.
- Contrasenas con PBKDF2-HMAC-SHA256 (600.000 iteraciones) y salt individual; comparacion con `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.
- Google Sign-In: el ID Token se valida en el servidor (`GoogleJsonWebSignature.ValidateAsync`) contra `GoogleAuth:ClientIds` y se exige correo verificado.
- La API no arranca si `Jwt:SecretKey` falta, es menor a 32 bytes o conserva el texto de relleno de `.env.example`.

### Manejo de errores

- Manejador global (`ManejadorErroresGlobal`) implementando `IExceptionHandler`.
- Todos los errores retornados como RFC 7807 `ProblemDetails`.
- Excepciones SQL traducidas: violacion FK (547) -> 400, constraint unico (2601/2627) -> 409.
- Detalles internos nunca expuestos al cliente.

### Orden del pipeline de middlewares

1. CORS
2. Authentication
3. Authorization
4. Rate Limiting
5. Controllers

## Endpoints disponibles

| Controlador | Ruta base | Responsabilidad | Auth | Rate Limit |
|---|---|---|---|---|
| UsuarioController | `/api/auth` | Registro, login con correo, login con Google, renovacion de sesion (`/refresh`, `/logout`) y sesion del Admin Console por cookie (`/web/login`, `/web/refresh`, `/web/logout`) | Publico | `auth` / `refresh` |
| CatalogoController | `/api/catalogos` | Cultivos, suelos, eventos, etapas | Publico | -- |
| ParcelaController | `/api/parcelas` | Gestion de parcelas | JWT | -- |
| ClimaController | `/api/clima` | Instantanea de clima en el servidor para una parcela (legado: la app ahora lee Open-Meteo directamente) | JWT | -- |
| UmbralConfiguracionController | `/api/umbrales` | Umbrales de riesgo | JWT | -- |
| MotorDecisionesController | `/api/motor` | Semaforo / resumen semanal en el servidor (legado: la app los calcula en el dispositivo) | JWT | `motor` |
| AlertaController | `/api/alertas` | La app reporta el evento que detecto en el dispositivo (auditoria) | JWT | `motor` |
| ReglaDecisionController | `/api/reglas` | Administracion del arbol (Admin); `GET /paquete` = paquete publico de reglas (ETag) para calcular en el dispositivo | JWT + Admin (salvo `GET /paquete`: Publico) | `publico` en `/paquete` |
| BitacoraController | `/api/logs` | Bitacora de campo | JWT | -- |
| Health | `/health` | Health check de infraestructura | Publico | -- |

Documentacion completa de cada endpoint en [docs/api-reference.md](../docs/api-reference.md).

## Comandos utiles

```bash
docker compose logs -f           # logs de todos los servicios
docker compose logs -f api       # logs solo de la API
docker compose build api && docker compose up -d api  # reconstruir solo la API
docker compose ps                # estado de los contenedores
docker compose down -v           # bajar todo y borrar volumenes
```

## Estructura del proyecto

```
backend/
|-- CosechaClima.sln
|-- Dockerfile                     # Multi-stage build (SDK -> Alpine)
|-- WebApi/
|   |-- Program.cs
|   |-- appsettings.json
|   |-- appsettings.Development.json
|   |-- Controllers/
|   |-- Dto/
|   |-- ManejadorErroresGlobal.cs
|   |-- ChequeoBaseDeDatos.cs
|-- WebApi.Models/
|-- Services/
|   |-- WebApi.Interface/
|   |-- WebApi.Implementation/
|-- Scripts/
|   |-- migrations/
|   |-- db-init/
|   |-- migracion-v2-auth.sql
|   |-- reglas-preliminares-completas.json
```

> [!NOTE]
> El archivo `compose.yaml` y `.env.example` estan en la raiz del monorepo, no dentro de `/backend`. Ver la [documentacion raiz](../README.es.md) para el quickstart global.

## Problemas comunes

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `db` queda `unhealthy` / la API dice `password authentication failed` | El volumen ya existia con otras contrasenas | `ALTER ROLE cosechaclima_app PASSWORD '...'`, o `docker compose down -v` (borra los datos) |
| La API dice `La migracion 'XXX' ya fue aplicada y el archivo cambio` | Se edito una migracion ya aplicada | Revertirla y crear una migracion nueva |
| `POST /api/auth/google` da `401` | Client IDs sin configurar, ID Token de otra app, o correo sin verificar | Revisar `GOOGLE_CLIENT_ID_*` y el log de la API; ver [docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |
| `api` se reinicia en loop | `Jwt:SecretKey` invalida, o falla la conexion a la base | Revisar logs; la clave debe tener 32+ bytes y no ser el texto de relleno |
| El admin no se crea | `ADMIN_SEED_EMAIL` invalido o `ADMIN_SEED_PASSWORD` de menos de 8 caracteres | Corregir los valores; el log muestra la advertencia y el seed se omite |
| `401` en todos los endpoints protegidos | Token faltante o expirado | Re-login, pegar `Bearer <token>` |
| `GET /api/umbrales/mios` da `404` | Usuario sin umbrales configurados | Comportamiento esperado, configurar primero |
| Frontend web no conecta | Origen no en CORS | Agregar origen a `Cors:AllowedOrigins` |

---

> [!WARNING]
> El `.env` de la raiz (y `mobile/.env`) contienen credenciales reales y nunca deben compartirse ni subirse a control de versiones. Al comprimir el proyecto, excluirlos explicitamente:
> ```bash
> zip -r CosechaClima.zip CosechaClima -x "*.env" -x "*/bin/*" -x "*/obj/*"
> ```