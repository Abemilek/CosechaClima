# CosechaClima -- Backend

<!-- README-I18N:START -->

**English** | [Español](./README.es.md)

<!-- README-I18N:END -->

REST API for CosechaClima, an early-warning weather system for small-scale corn and bean producers in Carazo, Nicaragua. ASP.NET Core 10, PostgreSQL 2022, ADO.NET.

---

## Table of Contents

- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Option A -- Run with Docker](#option-a----run-with-docker)
- [Option B -- Run locally without Docker](#option-b----run-locally-without-docker)
- [Configuration variables](#configuration-variables)
- [Admin user](#admin-user)
- [Schema migration: from phone + PIN to email + Google](#schema-migration-from-phone--pin-to-email--google)
- [Docker deployment -- multi-stage Dockerfile](#docker-deployment----multi-stage-dockerfile)
- [Architecture and security patterns](#architecture-and-security-patterns)
- [Available endpoints](#available-endpoints)
- [Useful commands](#useful-commands)
- [Project structure](#project-structure)
- [Troubleshooting](#troubleshooting)

---

## Architecture

```
CosechaClima.sln
|-- WebApi/                    # HTTP presentation layer
|   |-- Controllers/
|   |-- Dto/
|   |-- ManejadorErroresGlobal.cs
|   |-- Program.cs
|-- WebApi.Models/             # Domain entities
|-- Services/
|   |-- WebApi.Interface/      # Service contracts
|   |-- WebApi.Implementation/ # Business logic + Npgsql (raw SQL)
|       |-- Connection/        # ConnectionBD (NpgsqlDataSource), MigradorBD
|       |-- Security/          # HashPassword, TokenGenerator, GoogleTokenValidator
|       |-- Exceptions/        # RecursoNoEncontradoException, FlujoIncompletoException
|-- Scripts/
|   |-- migrations/            # 001_esquema_inicial.sql, 002_catalogos_base.sql, ...
|   |-- db-init/01-roles.sh    # crea el rol de la app (solo 1.a vez del volumen)
|   |-- reglas-preliminares-completas.json
|-- Dockerfile
```

## Tech Stack

| Component | Technology |
|---|---|
| Framework | ASP.NET Core 10 (.NET 10) |
| Database | PostgreSQL 18 |
| Data access | Npgsql 10 (`NpgsqlDataSource`) with explicit SQL, `INSERT ... ON CONFLICT` upserts and `jsonb_to_recordset` for batch operations |
| Authentication | JWT Bearer (email + password with PBKDF2 hash + salt, or Google Sign-In validated with `Google.Apis.Auth`; `Jti` claim) |
| Weather data | Open-Meteo (public API, no key) |
| API documentation | Swagger / OpenAPI |
| Containers | Docker multi-stage build (SDK -> Alpine runtime) |
| Error handling | RFC 7807 ProblemDetails via `ManejadorErroresGlobal` |

## Prerequisites

- [.NET SDK 10](https://dotnet.microsoft.com/download) (if you won't use Docker)
- [Docker + Docker Compose](https://www.docker.com/) (recommended)
- A PostgreSQL client for inspection (`psql`, DBeaver, pgAdmin, or the VS Code extension)

## Option A -- Run with Docker

> [!NOTE]
> The `compose.yaml` file lives in the **project root** (not inside `/backend`). All variables are read from the root `.env`.

```bash
cd CosechaClima   # project root
cp .env.example .env
# Edit .env -- see comments in .env.example
docker compose up --build -d
```

> [!WARNING]
> `DB_APP_PASSWORD` must be **exactly the same** password you write inside `CONNECTION_STRING`. `DB_ADMIN_PASSWORD` is the `postgres` superuser, reserved for administration; the API never uses it.

Containers start in order: **db** (PostgreSQL 18; the first time it creates the non-superuser `cosechaclima_app` role and its database) -> **api** (http://localhost:8080), which applies the SQL migrations in `Scripts/migrations` on startup before accepting requests.

> [!WARNING]
> PostgreSQL only applies the passwords **the first time** it initializes the `cosechaclima-db-data` volume. To change them later use `ALTER ROLE cosechaclima_app PASSWORD '...'`. In development, to start clean: `docker compose down -v && docker compose up --build` (**wipes data**).

> [!NOTE]
> The `postgres:18` image expects the volume at `/var/lib/postgresql` (not `/var/lib/postgresql/data` as in 17 and earlier); `compose.yaml` already does it that way.

Verification:

```bash
curl http://localhost:8080/health
```

Expected: `200 OK` with `Healthy`.

## Option B -- Run locally without Docker

### 1. Start only PostgreSQL

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

### 2. Configure the API

```bash
cd backend/WebApi
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:BD_CosechaClima" "Host=localhost;Port=5432;Database=cosechaclima;Username=cosechaclima_app;Password=app_local_pw"
dotnet user-secrets set "Jwt:SecretKey" "una-clave-larga-de-al-menos-32-caracteres-para-hmac-sha256"
# Optional: Google Sign-In (see docs/google-sign-in-setup.md)
dotnet user-secrets set "GoogleAuth:ClientIds:0" "<client id web>.apps.googleusercontent.com"
```

### 3. Run the API

```bash
cd backend/WebApi
dotnet run
```

It starts on `http://localhost:5013` (http profile). The schema and catalogs are created automatically (migrations).

## Configuration variables

| Key | Docker (`.env`) | Local (user-secrets) | Required |
|---|---|---|---|
| `ConnectionStrings:BD_CosechaClima` | `CONNECTION_STRING` | Yes | Yes (Npgsql format: `Host=...;Port=...;Database=...;Username=...;Password=...`) |
| `Jwt:SecretKey` | `JWT_SECRET_KEY` | Yes | Yes (min 32 characters for HMAC-SHA256) |
| `Jwt:Issuer` | `JWT_ISSUER` | Has default | No |
| `Jwt:Audience` | `JWT_AUDIENCE` | Has default | No |
| `Jwt:DurationMinutes` | `JWT_DURATION_MINUTES` | Has default (15) | No (the API warns if > 60) |
| `Jwt:RefreshDays` | `JWT_REFRESH_DAYS` | Has default (30) | No (sliding; absolute cap of 180 days per login) |
| `Auth:CookieSecure` | `AUTH_COOKIE_SECURE` | Has default (true) | No (set `false` only to test the Admin Console over plain http://localhost) |
| `Proxy:KnownProxies:0` | `PROXY_KNOWN_PROXY` | No | No (IP of your reverse proxy) |
| `Proxy:KnownNetworks:0` | `PROXY_KNOWN_NETWORK` | No | No (CIDR of your proxy network) |
| `AdminSeed:Email` | `ADMIN_SEED_EMAIL` | Yes | No (valid email) |
| `AdminSeed:Password` | `ADMIN_SEED_PASSWORD` | Yes | No (minimum 8 characters) |
| `AdminSeed:Nombre` | `ADMIN_SEED_NOMBRE` | Yes | No |
| `GoogleAuth:ClientIds:0` | `GOOGLE_CLIENT_ID_ANDROID` | Yes | No (required for Google Sign-In) |
| `GoogleAuth:ClientIds:1` | `GOOGLE_CLIENT_ID_IOS` | Yes | No |
| `GoogleAuth:ClientIds:2` | `GOOGLE_CLIENT_ID_WEB` | Yes | Yes for Google Sign-In: it is the `aud` of the token Google issues to the app |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | Yes | No |
| `ASPNETCORE_ENVIRONMENT` | `ASPNETCORE_ENVIRONMENT` | Yes | No (default `Production`: Swagger hidden; `Development` enables it) |

Empty Client IDs are ignored. If none is configured, `POST /api/auth/google` returns `401` and the API log says `GoogleAuth:ClientIds no esta configurado`. Email accounts work the same.

**Behind a proxy:** declare it with `Proxy:KnownProxies` / `Proxy:KnownNetworks`. Without that, `X-Forwarded-*` headers are ignored (so nobody can spoof their IP) and per-IP rate limiting would see only the proxy's address.

## Admin user

**Automatic (recommended):** fill in `ADMIN_SEED_EMAIL` and `ADMIN_SEED_PASSWORD` (and optionally `ADMIN_SEED_NOMBRE`) in `.env`. The email must be valid and the password at least 8 characters, otherwise the seed is skipped with a warning. On startup, if the user doesn't exist it is created with the Admin role; if it exists but isn't Admin, the role is granted.

**Manual:** register a normal user via `POST /api/auth/register` (or sign in with Google) and then:

```sql
UPDATE usuarios SET es_admin = true WHERE email = '<lowercase email>';
```

There is no HTTP endpoint to self-promote to admin -- that's an intentional design decision. The user must sign in again after the change.

## Database and migrations

The schema lives in plain SQL files: `Scripts/migrations/001_*.sql`, `002_*.sql`, ... On startup `MigradorBD` applies the pending ones in order, each inside a transaction, under a PostgreSQL advisory lock (two API instances can't migrate at once), and records version + checksum in `schema_migrations`.

- **Never edit an applied migration**: its checksum is verified and the API refuses to start if it changed. Create a new file instead (`004_...sql`).
- Reasons for PostgreSQL, raw SQL instead of an ORM, conventions and the upgrade path from the old SQL Server database: see [docs/postgresql.md](../docs/postgresql.md).

## Docker deployment -- multi-stage Dockerfile

The Dockerfile uses a multi-stage build:

- **Stage 1 (build):** `mcr.microsoft.com/dotnet/sdk:10.0` -- restores dependencies and publishes the app.
- **Stage 2 (runtime):** `mcr.microsoft.com/dotnet/aspnet:10.0-alpine` -- minimal Alpine image.
  - Runs as non-root user.
  - Minimal attack surface (no unnecessary shell utilities).
  - Drastically reduced image size compared to standard Debian images.

> [!NOTE]
> The healthcheck in `compose.yaml` uses `wget --spider -q http://localhost:8080/health` because Alpine doesn't ship `curl` by default.

## Architecture and security patterns

### Dependency injection

- `ConnectionBD` registered as `AddSingleton` -- wraps one `NpgsqlDataSource` (the connection pool, thread-safe by design) and hands out a new connection per call that goes back to the pool when disposed.
- All business services registered as `AddScoped`.

### Data access practices

- Exclusively parameterized queries (zero string concatenation in SQL).
- `jsonb_to_recordset` for the batch in `ReglaDecisionService.AplicarContenidoPreliminar` (one UPDATE instead of N+1); by default it only fills rules still `PENDIENTE`, so it no longer overwrites what an admin edited.
- Upserts with `INSERT ... ON CONFLICT DO UPDATE` (thresholds, alerts, weather) instead of read-then-write: atomic under concurrency.
- The 540 active rules are cached in memory (`IMemoryCache`) and invalidated when an admin edits them; before, each lookup opened a connection.
- Explicit `ORDER BY` on every list: PostgreSQL does not guarantee order without it.
- All connections wrapped in `using` blocks ensuring deterministic disposal.

### Rate limiting

| Policy | Window | Limit | Endpoints |
|---|---|---|---|
| `auth` | Sliding, 1 minute | 5 requests per IP | `/api/auth/register`, `/api/auth/login`, `/api/auth/google`, `/api/auth/web/login` |
| `refresh` | Sliding, 1 minute | 30 requests per IP | `/api/auth/refresh`, `/api/auth/logout`, `/api/auth/web/refresh` |
| `publico` | Sliding, 1 minute | 30 requests per IP | `GET /api/reglas/paquete` |
| `motor` | Applied to the controller | Prevents abuse | `/api/motor/semaforo` |

> [!WARNING]
> The per-IP policies count by the connection's source IP. Behind a proxy declare it in `Proxy:KnownProxies` / `Proxy:KnownNetworks` so the real client IP is read from `X-Forwarded-For`; otherwise the limit becomes global. See [docs/security.md](../docs/security.md).

### JWT security

- Signed with HMAC-SHA256, secret key minimum 32 characters.
- `Jti` (JWT ID) claim for token uniqueness and replay attack prevention.
- Short-lived access token (default **15 minutes**, 30 s clock skew) plus an opaque, single-use **refresh token** (SHA-256 stored, rotated on every use, family revoked on reuse; 30 days sliding, 180 absolute). Admin Console: refresh token in an `HttpOnly` `SameSite=Strict` cookie.
- Passwords with PBKDF2-HMAC-SHA256 (600,000 iterations) and per-user salt; comparison with `CryptographicOperations.FixedTimeEquals` to mitigate timing attacks.
- Google Sign-In: the ID Token is validated on the server (`GoogleJsonWebSignature.ValidateAsync`) against `GoogleAuth:ClientIds`, and a verified email is required.
- The API won't start if `Jwt:SecretKey` is missing, is shorter than 32 bytes, or still holds the placeholder text from `.env.example`.

### Error handling

- Global handler (`ManejadorErroresGlobal`) implementing `IExceptionHandler`.
- All errors returned as RFC 7807 `ProblemDetails`.
- SQL exceptions translated: FK violation (547) -> 400, unique constraint (2601/2627) -> 409.
- Internal details never exposed to the client.

### Middleware pipeline order

1. CORS
2. Authentication
3. Authorization
4. Rate Limiting
5. Controllers

## Available endpoints

| Controller | Base route | Responsibility | Auth | Rate limit |
|---|---|---|---|---|
| UsuarioController | `/api/auth` | Registration, email login, Google login, session renewal (`/refresh`, `/logout`) and cookie-based adminconsole session (`/web/login`, `/web/refresh`, `/web/logout`) | Public | `auth` / `refresh` |
| CatalogoController | `/api/catalogos` | Crops, soils, events, stages | Public | -- |
| ParcelaController | `/api/parcelas` | Plot management | JWT | -- |
| ClimaController | `/api/clima` | Server-side weather snapshot of a plot (legacy: the app now reads Open-Meteo directly) | JWT | -- |
| UmbralConfiguracionController | `/api/umbrales` | Risk thresholds | JWT | -- |
| MotorDecisionesController | `/api/motor` | Server-side traffic light / weekly summary (legacy: the app computes them on the device) | JWT | `motor` |
| AlertaController | `/api/alertas` | The app reports the event it detected on-device (audit trail) | JWT | `motor` |
| ReglaDecisionController | `/api/reglas` | Tree management (Admin); `GET /paquete` = public rules package (ETag) for on-device calculation | JWT + Admin (except `GET /paquete`: Public) | `publico` on `/paquete` |
| BitacoraController | `/api/logs` | Field logbook | JWT | -- |
| Health | `/health` | Infrastructure health check | Public | -- |

Full documentation of each endpoint in [docs/api-reference.md](../docs/api-reference.md).

## Useful commands

```bash
docker compose logs -f           # logs from all services
docker compose logs -f api       # API logs only
docker compose build api && docker compose up -d api  # rebuild only the API
docker compose ps                # container status
docker compose down -v           # stop everything and delete volumes
```

## Project structure

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
> The `compose.yaml` file and `.env.example` live in the monorepo root, not inside `/backend`. See the [root documentation](../README.md) for the global quickstart.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| `db` stays `unhealthy` / the API says `password authentication failed` | The volume already existed with other passwords | `ALTER ROLE cosechaclima_app PASSWORD '...'`, or `docker compose down -v` (wipes data) |
| The API says `La migracion 'XXX' ya fue aplicada y el archivo cambio` | An applied migration file was edited | Revert it and add a new migration |
| `POST /api/auth/google` returns `401` | Client IDs not configured, ID Token from another app, or unverified email | Check `GOOGLE_CLIENT_ID_*` and the API log; see [docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |
| `api` restarts in a loop | Invalid `Jwt:SecretKey`, or database connection failure | Check logs; the key must be 32+ bytes and not the placeholder text |
| Admin is not created | Invalid `ADMIN_SEED_EMAIL` or `ADMIN_SEED_PASSWORD` shorter than 8 characters | Fix the values; the log shows the warning and the seed is skipped |
| `401` on all protected endpoints | Missing or expired token | Sign in again, paste `Bearer <token>` |
| `GET /api/umbrales/mios` returns `404` | User with no configured thresholds | Expected behavior, configure them first |
| `POST /api/motor/semaforo` returns `404` | Missing weather data or thresholds | Call `POST /api/clima/actualizar` first |
| Web frontend can't connect | Origin not in CORS | Add origin to `Cors:AllowedOrigins` |

---

> [!WARNING]
> The root `.env` (and `mobile/.env`) hold real credentials and must never be shared or pushed to version control. When zipping the project, exclude them explicitly:
> ```bash
> zip -r CosechaClima.zip CosechaClima -x "*.env" -x "*/bin/*" -x "*/obj/*"
> ```