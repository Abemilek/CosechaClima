# CosechaClima -- Backend

API REST para CosechaClima, un sistema de alerta temprana climatica para pequenos productores de maiz y frijol en Carazo, Nicaragua. ASP.NET Core 10, SQL Server 2022, ADO.NET.

---

## Tabla de contenidos

- [Arquitectura](#arquitectura)
- [Stack tecnico](#stack-tecnico)
- [Requisitos previos](#requisitos-previos)
- [Opcion A -- Ejecutar con Docker](#opcion-a----ejecutar-con-docker)
- [Opcion B -- Ejecutar localmente sin Docker](#opcion-b----ejecutar-localmente-sin-docker)
- [Variables de configuracion](#variables-de-configuracion)
- [Usuario administrador](#usuario-administrador)
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
|   |-- WebApi.Implementation/ # Logica de negocio + ADO.NET
|       |-- Connection/        # ConnectionBD (fabrica de SqlConnection)
|       |-- Security/          # HashPin, TokenGenerator
|       |-- Exceptions/        # RecursoNoEncontradoException, FlujoIncompletoException
|-- Scripts/
|   |-- BD-CosechaClima.sql
|   |-- seed.sql
|   |-- reglas-preliminares-completas.json
|-- Dockerfile
```

## Stack tecnico

| Componente | Tecnologia |
|---|---|
| Framework | ASP.NET Core 10 (.NET 10) |
| Base de datos | SQL Server 2022 |
| Acceso a datos | ADO.NET (`Microsoft.Data.SqlClient`) con `OPENJSON` para operaciones batch |
| Autenticacion | JWT Bearer (PIN con hash PBKDF2 + salt, claim `Jti`) |
| Datos climaticos | Open-Meteo (API publica, sin key) |
| Documentacion de API | Swagger / OpenAPI |
| Contenedores | Docker multi-stage build (SDK -> Alpine runtime) |
| Manejo de errores | RFC 7807 ProblemDetails via `ManejadorErroresGlobal` |

## Requisitos previos

- [.NET SDK 10](https://dotnet.microsoft.com/download) (si no usaras Docker)
- [Docker + Docker Compose](https://www.docker.com/) (recomendado)
- Un cliente de SQL Server para inspeccion (Azure Data Studio, DBeaver, o extension de VS Code)

## Opcion A -- Ejecutar con Docker

> [!NOTE]
> El archivo `compose.yaml` esta en la **raiz del proyecto** (no dentro de `/backend`). Todas las variables se leen del `.env` en la raiz.

```bash
cd CosechaClima   # raiz del proyecto
cp .env.example .env
# Editar .env -- ver comentarios en .env.example
docker compose up --build -d
```

> [!WARNING]
> `DB_SA_PASSWORD` debe cumplir la politica de complejidad de SQL Server: minimo 8 caracteres combinando al menos 3 de 4 categorias (mayusculas, minusculas, digitos, simbolos). Una contrasena que no cumpla causara que el contenedor `db` falle con `Login failed for user 'sa'`.

Los contenedores se inician en orden: **db** -> **db-init** (esquema + seed) -> **api** (http://localhost:8080).

Verificacion:

```bash
curl http://localhost:8080/health
```

Esperado: `200 OK` con `Healthy`.

## Opcion B -- Ejecutar localmente sin Docker

### 1. Levantar solo SQL Server

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=YourStrong!Passw0rd" \
  -p 1433:1433 --name cosechaclima-db-local \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 2. Correr los scripts

Conectarse a `localhost,1433` con usuario `sa` y ejecutar en orden: `Scripts/BD-CosechaClima.sql` y luego `Scripts/seed.sql`.

### 3. Configurar la API

```bash
cd backend/WebApi
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:BD_CosechaClima" "Server=localhost,1433;Database=BD_CosechaClima;User Id=sa;Password=YourStrong!Passw0rd;TrustServerCertificate=True;"
dotnet user-secrets set "Jwt:SecretKey" "una-clave-larga-de-al-menos-32-caracteres-para-hmac-sha256"
```

### 4. Correr la API

```bash
cd backend/WebApi
dotnet run
```

Levanta en `http://localhost:5013` (perfil http).

## Variables de configuracion

| Clave | Docker (`.env`) | Local (user-secrets) | Requerida |
|---|---|---|---|
| `ConnectionStrings:BD_CosechaClima` | `CONNECTION_STRING` | Si | Si |
| `Jwt:SecretKey` | `JWT_SECRET_KEY` | Si | Si (min 32 caracteres para HMAC-SHA256) |
| `Jwt:Issuer` | `JWT_ISSUER` | Tiene default | No |
| `Jwt:Audience` | `JWT_AUDIENCE` | Tiene default | No |
| `Jwt:DurationMinutes` | `JWT_DURATION_MINUTES` | Tiene default (1440) | No |
| `AdminSeed:Telefono` | `ADMIN_SEED_TELEFONO` | Si | No (8 digitos) |
| `AdminSeed:Pin` | `ADMIN_SEED_PIN` | Si | No (4 digitos) |
| `AdminSeed:Nombre` | `ADMIN_SEED_NOMBRE` | Si | No |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | Si | No |

## Usuario administrador

**Automatico (recomendado):** completar `ADMIN_SEED_TELEFONO` y `ADMIN_SEED_PIN` en `.env`. Al arrancar, si el usuario no existe se crea con rol Admin; si existe pero no es Admin, se le otorga el rol.

**Manual:** registrar un usuario normal por `POST /api/auth/register` y luego:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Telefono = '<telefono>';
```

No existe ningun endpoint HTTP para auto-promoverse a administrador -- es una decision de diseno intencional. El usuario debe re-iniciar sesion despues del cambio.

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

- `ConnectionBD` registrado como `AddSingleton` -- actua como fabrica que crea nuevas instancias de `SqlConnection` por cada llamada. Es thread-safe porque crea conexiones, no las comparte.
- Todos los servicios de negocio registrados como `AddScoped`.

### Optimizaciones ADO.NET

- Queries parametrizadas exclusivamente (cero concatenacion de strings en SQL).
- `OPENJSON` para operaciones batch en `ReglaDecisionService.AplicarContenidoPreliminar`, reemplazando N+1 UPDATEs individuales con un unico batch T-SQL.
- Todas las conexiones envueltas en bloques `using` asegurando liberacion determinista.

### Rate Limiting

| Politica | Ventana | Limite | Endpoints |
|---|---|---|---|
| `auth` | Deslizante, 1 minuto | 5 peticiones por IP | `/api/auth/register`, `/api/auth/login` |
| `motor` | Aplicada al controlador | Previene abuso | `/api/motor/semaforo` |

### Seguridad JWT

- Firmado con HMAC-SHA256, clave secreta minimo 32 caracteres.
- Claim `Jti` (JWT ID) para unicidad de token y prevencion de replay attacks.
- Expiracion configurable (default 24 horas).
- Comparacion de PIN con `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.

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
| UsuarioController | `/api/auth` | Registro y login | Publico | `auth` |
| CatalogoController | `/api/catalogos` | Cultivos, suelos, eventos, etapas | JWT | -- |
| ParcelaController | `/api/parcelas` | Gestion de parcelas | JWT | -- |
| ClimaController | `/api/clima` | Datos climaticos | JWT | -- |
| UmbralConfiguracionController | `/api/umbrales` | Umbrales de riesgo | JWT | -- |
| MotorDecisionesController | `/api/motor` | Calculo de semaforo de riesgo | JWT | `motor` |
| ReglaDecisionController | `/api/reglas` | Administracion del arbol (Admin) | JWT + Admin | -- |
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
|   |-- BD-CosechaClima.sql
|   |-- seed.sql
|   |-- reglas-preliminares-completas.json
```

> [!NOTE]
> El archivo `compose.yaml` y `.env.example` estan en la raiz del monorepo, no dentro de `/backend`. Ver la [documentacion raiz](../README.md) para el quickstart global.

## Problemas comunes

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `db` sale con "password validation failed" | `DB_SA_PASSWORD` no cumple complejidad | Usar 8+ caracteres con 3/4 categorias |
| `api` se reinicia en loop | Formato invalido en AdminSeed | Revisar logs, corregir valores |
| `401` en todos los endpoints protegidos | Token faltante o expirado | Re-login, pegar `Bearer <token>` |
| `GET /api/umbrales/mios` da `404` | Usuario sin umbrales configurados | Comportamiento esperado, configurar primero |
| `POST /api/motor/semaforo` da `404` | Faltan datos climaticos o umbrales | Llamar `POST /api/clima/actualizar` primero |
| Frontend web no conecta | Origen no en CORS | Agregar origen a `Cors:AllowedOrigins` |

---

> [!WARNING]
> `backend/.env` nunca debe compartirse ni subirse a control de versiones. Al comprimir el proyecto, excluirlo explicitamente:
> ```bash
> zip -r CosechaClima.zip CosechaClima -x "*.env" -x "*/bin/*" -x "*/obj/*"
> ```