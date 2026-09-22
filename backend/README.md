# CosechaClima -- Backend

<!-- README-I18N:START -->

**English** | [Español](./README.es.md)

<!-- README-I18N:END -->

REST API for CosechaClima, an early-warning weather system for small-scale corn and bean producers in Carazo, Nicaragua. ASP.NET Core 10, SQL Server 2022, ADO.NET.

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
|   |-- WebApi.Implementation/ # Business logic + ADO.NET
|       |-- Connection/        # ConnectionBD (SqlConnection factory)
|       |-- Security/          # HashPassword, TokenGenerator, GoogleTokenValidator
|       |-- Exceptions/        # RecursoNoEncontradoException, FlujoIncompletoException
|-- Scripts/
|   |-- BD-CosechaClima.sql
|   |-- seed.sql
|   |-- reglas-preliminares-completas.json
|-- Dockerfile
```

## Tech Stack

| Component | Technology |
|---|---|
| Framework | ASP.NET Core 10 (.NET 10) |
| Database | SQL Server 2022 |
| Data access | ADO.NET (`Microsoft.Data.SqlClient`) with `OPENJSON` for batch operations |
| Authentication | JWT Bearer (email + password with PBKDF2 hash + salt, or Google Sign-In validated with `Google.Apis.Auth`; `Jti` claim) |
| Weather data | Open-Meteo (public API, no key) |
| API documentation | Swagger / OpenAPI |
| Containers | Docker multi-stage build (SDK -> Alpine runtime) |
| Error handling | RFC 7807 ProblemDetails via `ManejadorErroresGlobal` |

## Prerequisites

- [.NET SDK 10](https://dotnet.microsoft.com/download) (if you won't use Docker)
- [Docker + Docker Compose](https://www.docker.com/) (recommended)
- A SQL Server client for inspection (Azure Data Studio, DBeaver, or the VS Code extension)

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
> `DB_SA_PASSWORD` must meet the SQL Server complexity policy: minimum 8 characters combining at least 3 of 4 categories (uppercase, lowercase, digits, symbols). A password that doesn't comply will make the `db` container fail with `Login failed for user 'sa'`.

Containers start in order: **db** -> **db-init** (schema + seed) -> **api** (http://localhost:8080).

> [!WARNING]
> SQL Server only applies `DB_SA_PASSWORD` **the first time** it creates the `cosechaclima-db-data` volume. If you change the password afterwards, `db` becomes `unhealthy` with `Login failed for user 'sa'`. The SQL scripts don't alter tables that already exist either. In development, to start clean: `docker compose down -v && docker compose up --build` (**wipes data**).

Verification:

```bash
curl http://localhost:8080/health
```

Expected: `200 OK` with `Healthy`.

## Option B -- Run locally without Docker

### 1. Start only SQL Server

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong!Passw0rd" \
  -p 1433:1433 --name cosechaclima-db-local \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 2. Run the scripts

Connect to `localhost,1433` with user `sa` and run in order: `Scripts/BD-CosechaClima.sql` and then `Scripts/seed.sql`.

### 3. Configure the API

```bash
cd backend/WebApi
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:BD_CosechaClima" "Server=localhost,1433;Database=BD_CosechaClima;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;"
dotnet user-secrets set "Jwt:SecretKey" "una-clave-larga-de-al-menos-32-caracteres-para-hmac-sha256"
# Optional: Google Sign-In (see docs/google-sign-in-setup.md)
dotnet user-secrets set "GoogleAuth:ClientIds:0" "<client id web>.apps.googleusercontent.com"
```

### 4. Run the API

```bash
cd backend/WebApi
dotnet run
```

It starts on `http://localhost:5013` (http profile).

## Configuration variables

| Key | Docker (`.env`) | Local (user-secrets) | Required |
|---|---|---|---|
| `ConnectionStrings:BD_CosechaClima` | `CONNECTION_STRING` | Yes | Yes |
| `Jwt:SecretKey` | `JWT_SECRET_KEY` | Yes | Yes (min 32 characters for HMAC-SHA256) |
| `Jwt:Issuer` | `JWT_ISSUER` | Has default | No |
| `Jwt:Audience` | `JWT_AUDIENCE` | Has default | No |
| `Jwt:DurationMinutes` | `JWT_DURATION_MINUTES` | Has default (1440) | No |
| `AdminSeed:Email` | `ADMIN_SEED_EMAIL` | Yes | No (valid email) |
| `AdminSeed:Password` | `ADMIN_SEED_PASSWORD` | Yes | No (minimum 8 characters) |
| `AdminSeed:Nombre` | `ADMIN_SEED_NOMBRE` | Yes | No |
| `GoogleAuth:ClientIds:0` | `GOOGLE_CLIENT_ID_ANDROID` | Yes | No (required for Google Sign-In) |
| `GoogleAuth:ClientIds:1` | `GOOGLE_CLIENT_ID_IOS` | Yes | No |
| `GoogleAuth:ClientIds:2` | `GOOGLE_CLIENT_ID_WEB` | Yes | Yes for Google Sign-In: it is the `aud` of the token Google issues to the app |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | Yes | No |
| `ASPNETCORE_ENVIRONMENT` | `ASPNETCORE_ENVIRONMENT` | Yes | No (default `Production`: Swagger hidden; `Development` enables it) |

Empty Client IDs are ignored. If none is configured, `POST /api/auth/google` returns `401` and the API log says `GoogleAuth:ClientIds no esta configurado`. Email accounts work the same.

## Admin user

**Automatic (recommended):** fill in `ADMIN_SEED_EMAIL` and `ADMIN_SEED_PASSWORD` (and optionally `ADMIN_SEED_NOMBRE`) in `.env`. The email must be valid and the password at least 8 characters, otherwise the seed is skipped with a warning. On startup, if the user doesn't exist it is created with the Admin role; if it exists but isn't Admin, the role is granted.

**Manual:** register a normal user via `POST /api/auth/register` (or sign in with Google) and then:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Email = '<lowercase email>';
```

There is no HTTP endpoint to self-promote to admin -- that's an intentional design decision. The user must sign in again after the change.

## Schema migration: from phone + PIN to email + Google

A **new** database needs no migration: `BD-CosechaClima.sql` already creates the schema with `Email`, `GoogleUid`, `PasswordHash`, `PasswordSalt`, `Proveedor` and `FotoUrl` (and `GoogleUid` uniqueness as a filtered unique index, which allows many email accounts without a Google UID).

For an **existing** database with the old schema:

```bash
sqlcmd -S localhost -U sa -P "TU_PASSWORD" -d BD_CosechaClima -i Scripts/migracion-v2-auth.sql
```

The script backs up `Usuarios` into `Usuarios_Respaldo_v1`, adds the new columns and drops `Telefono`, `PinHash` and `PinSalt`. Old accounts are left **deactivated** with a placeholder email `migrado-<telefono>@cosechaclima.invalid`: their PINs no longer work, so each person must register again and their plots must be reassigned manually if you want to keep them (the script itself prints the sample `UPDATE`). Review the backup before deleting it.

In development, if there is no data to keep, `docker compose down -v` is simpler.

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

- `ConnectionBD` registered as `AddSingleton` -- acts as a factory that creates new `SqlConnection` instances per call. It's thread-safe because it creates connections, it doesn't share them.
- All business services registered as `AddScoped`.

### ADO.NET optimizations

- Exclusively parameterized queries (zero string concatenation in SQL).
- `OPENJSON` for batch operations in `ReglaDecisionService.AplicarContenidoPreliminar`, replacing N+1 individual UPDATEs with a single T-SQL batch.
- All connections wrapped in `using` blocks ensuring deterministic disposal.

### Rate limiting

| Policy | Window | Limit | Endpoints |
|---|---|---|---|
| `auth` | Sliding, 1 minute | 5 requests per IP | `/api/auth/register`, `/api/auth/login`, `/api/auth/google` |
| `motor` | Applied to the controller | Prevents abuse | `/api/motor/semaforo` |

> [!WARNING]
> `auth` counts by the connection's source IP. Behind a proxy or tunnel (ngrok, etc.) all clients share the IP and the limit becomes global. See [docs/security.md](../docs/security.md).

### JWT security

- Signed with HMAC-SHA256, secret key minimum 32 characters.
- `Jti` (JWT ID) claim for token uniqueness and replay attack prevention.
- Configurable expiration (default 24 hours).
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
| UsuarioController | `/api/auth` | Registration, email login and Google login | Public | `auth` |
| CatalogoController | `/api/catalogos` | Crops, soils, events, stages | Public | -- |
| ParcelaController | `/api/parcelas` | Plot management | JWT | -- |
| ClimaController | `/api/clima` | Plot weather data; `GET /pronostico` is the public coordinate-based forecast (guest mode) | JWT (except `GET /pronostico`: Public) | -- |
| UmbralConfiguracionController | `/api/umbrales` | Risk thresholds | JWT | -- |
| MotorDecisionesController | `/api/motor` | Risk traffic-light calculation | JWT | `motor` |
| ReglaDecisionController | `/api/reglas` | Tree management (Admin) | JWT + Admin | -- |
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
|   |-- BD-CosechaClima.sql
|   |-- seed.sql
|   |-- migracion-v2-auth.sql
|   |-- reglas-preliminares-completas.json
```

> [!NOTE]
> The `compose.yaml` file and `.env.example` live in the monorepo root, not inside `/backend`. See the [root documentation](../README.md) for the global quickstart.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| `db` exits with "password validation failed" | `DB_SA_PASSWORD` doesn't meet complexity | Use 8+ characters with 3/4 categories |
| `db` stays `unhealthy` with `Login failed for user 'sa'` | The volume already existed with another password | `docker compose down -v` and start again (wipes data) |
| `POST /api/auth/register` returns `409` with a new email | The database has a plain `UNIQUE` constraint on `GoogleUid` (only allows one `NULL`) | Recreate the database with the current `BD-CosechaClima.sql` (filtered unique index) |
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