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
|   |-- WebApi.Implementation/ # Logica de negocio + ADO.NET
|       |-- Connection/        # ConnectionBD (fabrica de SqlConnection)
|       |-- Security/          # HashPassword, TokenGenerator, GoogleTokenValidator
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
| Autenticacion | JWT Bearer (correo + contrasena con hash PBKDF2 + salt, o Google Sign-In validado con `Google.Apis.Auth`; claim `Jti`) |
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

> [!WARNING]
> SQL Server solo aplica `DB_SA_PASSWORD` **la primera vez** que crea el volumen `cosechaclima-db-data`. Si cambias la contrasena despues, `db` queda `unhealthy` con `Login failed for user 'sa'`. Los scripts SQL tampoco alteran tablas que ya existen. En desarrollo, para empezar limpio: `docker compose down -v && docker compose up --build` (**borra los datos**).

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
# Opcional: Google Sign-In (ver docs/google-sign-in-setup.md)
dotnet user-secrets set "GoogleAuth:ClientIds:0" "<client id web>.apps.googleusercontent.com"
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
| `AdminSeed:Email` | `ADMIN_SEED_EMAIL` | Si | No (correo valido) |
| `AdminSeed:Password` | `ADMIN_SEED_PASSWORD` | Si | No (minimo 8 caracteres) |
| `AdminSeed:Nombre` | `ADMIN_SEED_NOMBRE` | Si | No |
| `GoogleAuth:ClientIds:0` | `GOOGLE_CLIENT_ID_ANDROID` | Si | No (necesario para Google Sign-In) |
| `GoogleAuth:ClientIds:1` | `GOOGLE_CLIENT_ID_IOS` | Si | No |
| `GoogleAuth:ClientIds:2` | `GOOGLE_CLIENT_ID_WEB` | Si | Si para Google Sign-In: es el `aud` del token que emite Google a la app |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | Si | No |
| `ASPNETCORE_ENVIRONMENT` | `ASPNETCORE_ENVIRONMENT` | Si | No (default `Production`: Swagger oculto; `Development` lo habilita) |

Los Client IDs vacios se ignoran. Si no hay ninguno configurado, `POST /api/auth/google` responde `401` y el log de la API indica `GoogleAuth:ClientIds no esta configurado`. Las cuentas de correo funcionan igual.

## Usuario administrador

**Automatico (recomendado):** completar `ADMIN_SEED_EMAIL` y `ADMIN_SEED_PASSWORD` (y opcionalmente `ADMIN_SEED_NOMBRE`) en `.env`. El correo debe ser valido y la contrasena de al menos 8 caracteres, o el seed se omite con una advertencia. Al arrancar, si el usuario no existe se crea con rol Admin; si existe pero no es Admin, se le otorga el rol.

**Manual:** registrar un usuario normal por `POST /api/auth/register` (o entrar con Google) y luego:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Email = '<correo en minusculas>';
```

No existe ningun endpoint HTTP para auto-promoverse a administrador -- es una decision de diseno intencional. El usuario debe re-iniciar sesion despues del cambio.

## Migracion de esquema: de telefono + PIN a correo + Google

Una base **nueva** no necesita migracion: `BD-CosechaClima.sql` ya crea el esquema con `Email`, `GoogleUid`, `PasswordHash`, `PasswordSalt`, `Proveedor` y `FotoUrl` (y la unicidad de `GoogleUid` como indice unico filtrado, que permite muchas cuentas de correo sin UID de Google).

Para una base **existente** con el esquema anterior:

```bash
sqlcmd -S localhost -U sa -P "TU_PASSWORD" -d BD_CosechaClima -i Scripts/migracion-v2-auth.sql
```

El script respalda `Usuarios` en `Usuarios_Respaldo_v1`, agrega las columnas nuevas y elimina `Telefono`, `PinHash` y `PinSalt`. Las cuentas viejas quedan **desactivadas** con un correo provisional `migrado-<telefono>@cosechaclima.invalid`: sus PIN ya no sirven, asi que cada persona debe registrarse de nuevo y sus parcelas hay que reasignarlas a mano si se quieren conservar (el propio script imprime el `UPDATE` de ejemplo). Revisa el respaldo antes de borrarlo.

En desarrollo, si no hay datos que conservar, es mas simple `docker compose down -v`.

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
| `auth` | Deslizante, 1 minuto | 5 peticiones por IP | `/api/auth/register`, `/api/auth/login`, `/api/auth/google` |
| `motor` | Aplicada al controlador | Previene abuso | `/api/motor/semaforo` |

> [!WARNING]
> `auth` cuenta por la IP de origen de la conexion. Detras de un proxy o tunel (ngrok, etc.) todos los clientes comparten IP y el limite pasa a ser global. Ver [docs/security.md](../docs/security.md).

### Seguridad JWT

- Firmado con HMAC-SHA256, clave secreta minimo 32 caracteres.
- Claim `Jti` (JWT ID) para unicidad de token y prevencion de replay attacks.
- Expiracion configurable (default 24 horas).
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
| UsuarioController | `/api/auth` | Registro, login con correo y login con Google | Publico | `auth` |
| CatalogoController | `/api/catalogos` | Cultivos, suelos, eventos, etapas | Publico | -- |
| ParcelaController | `/api/parcelas` | Gestion de parcelas | JWT | -- |
| ClimaController | `/api/clima` | Datos climaticos de una parcela; `GET /pronostico` es el pronostico publico por coordenadas (modo invitado) | JWT (salvo `GET /pronostico`: Publico) | -- |
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
|   |-- migracion-v2-auth.sql
|   |-- reglas-preliminares-completas.json
```

> [!NOTE]
> El archivo `compose.yaml` y `.env.example` estan en la raiz del monorepo, no dentro de `/backend`. Ver la [documentacion raiz](../README.md) para el quickstart global.

## Problemas comunes

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `db` sale con "password validation failed" | `DB_SA_PASSWORD` no cumple complejidad | Usar 8+ caracteres con 3/4 categorias |
| `db` queda `unhealthy` con `Login failed for user 'sa'` | El volumen ya existia con otra contrasena | `docker compose down -v` y volver a levantar (borra los datos) |
| `POST /api/auth/register` da `409` con un correo nuevo | La base tiene `GoogleUid` con una restriccion `UNIQUE` comun (solo admite un `NULL`) | Recrear la base con el `BD-CosechaClima.sql` actual (indice unico filtrado) |
| `POST /api/auth/google` da `401` | Client IDs sin configurar, ID Token de otra app, o correo sin verificar | Revisar `GOOGLE_CLIENT_ID_*` y el log de la API; ver [docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |
| `api` se reinicia en loop | `Jwt:SecretKey` invalida, o falla la conexion a la base | Revisar logs; la clave debe tener 32+ bytes y no ser el texto de relleno |
| El admin no se crea | `ADMIN_SEED_EMAIL` invalido o `ADMIN_SEED_PASSWORD` de menos de 8 caracteres | Corregir los valores; el log muestra la advertencia y el seed se omite |
| `401` en todos los endpoints protegidos | Token faltante o expirado | Re-login, pegar `Bearer <token>` |
| `GET /api/umbrales/mios` da `404` | Usuario sin umbrales configurados | Comportamiento esperado, configurar primero |
| `POST /api/motor/semaforo` da `404` | Faltan datos climaticos o umbrales | Llamar `POST /api/clima/actualizar` primero |
| Frontend web no conecta | Origen no en CORS | Agregar origen a `Cors:AllowedOrigins` |

---

> [!WARNING]
> El `.env` de la raiz (y `mobile/.env`) contienen credenciales reales y nunca deben compartirse ni subirse a control de versiones. Al comprimir el proyecto, excluirlos explicitamente:
> ```bash
> zip -r CosechaClima.zip CosechaClima -x "*.env" -x "*/bin/*" -x "*/obj/*"
> ```