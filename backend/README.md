<p align="center">
  <img src="../docs/assets/cosechaclima-logo.svg" alt="CosechaClima" width="130">
</p>

<h1 align="center">CosechaClima — Backend</h1>

API REST para **CosechaClima**, un sistema de alerta temprana climática para pequeños productores de maíz y frijol en Carazo, Nicaragua. Cruza datos climáticos con la etapa fenológica del cultivo del usuario y devuelve recomendaciones priorizadas mediante un sistema de semáforo (verde / amarillo / rojo).

<p align="center">
  <img alt=".NET" src="https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet&logoColor=white">
  <img alt="SQL Server" src="https://img.shields.io/badge/SQL_Server-2022-CC2927?logo=microsoftsqlserver&logoColor=white">
  <img alt="Docker" src="https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white">
  <img alt="Status" src="https://img.shields.io/badge/status-en%20desarrollo-yellow">
</p>

---

## Tabla de contenidos

- [Arquitectura](#arquitectura)
- [Stack técnico](#stack-técnico)
- [Requisitos previos](#requisitos-previos)
- [Opción A — Ejecutar con Docker](#opción-a--ejecutar-con-docker)
- [Opción B — Ejecutar localmente sin Docker](#opción-b--ejecutar-localmente-sin-docker)
- [Variables y claves de configuración](#variables-y-claves-de-configuración)
- [Cómo conseguir un usuario Admin](#cómo-conseguir-un-usuario-admin)
- [Swagger y autenticación](#swagger-y-autenticación)
- [CORS](#cors)
- [Endpoints disponibles](#endpoints-disponibles)
- [Comandos útiles](#comandos-útiles)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Problemas comunes](#problemas-comunes)

---

## Arquitectura

```
CosechaClima.sln
│
├── WebApi.Models/              
│
├── Services/
│   ├── WebApi.Interface/       
│   └── WebApi.Implementation/  
│
└── WebApi/                  
```

## Stack técnico

| Componente | Tecnología |
|---|---|
| Framework | ASP.NET Core (.NET 10) |
| Base de datos | SQL Server 2022 |
| Acceso a datos | ADO.NET (`Microsoft.Data.SqlClient`) |
| Autenticación | JWT Bearer (PIN de 4 dígitos, hash PBKDF2) |
| Datos climáticos | Open-Meteo (API pública, sin key) |
| Documentación de API | Swagger / OpenAPI, con botón "Authorize" para JWT |
| Contenedores | Docker + Docker Compose |

## Requisitos previos

- [.NET SDK 10](https://dotnet.microsoft.com/download) (si no usaras docker)
- [Docker + Docker Compose](https://www.docker.com/) (si usaras docker es lo recomendado)
- Un cliente de SQL Server para inspeccionar la base si hace falta (Azure Data Studio, DBeaver, o la extensión "SQL Server" de VS Code)

## Opción A — Ejecutar con Docker

### Qué configurar antes de `docker compose up --build`

**Solo el `.env`.** No hace falta tocar ningún archivo `.json` — `docker-compose.yml` inyecta la configuración como variables de entorno, que tienen prioridad sobre `appsettings.*.json`.

```bash
cd backend
cp .env.example .env
```

Completá como mínimo:

```bash
DB_SA_PASSWORD=elegí-una-clave-que-cumpla-la-politica-de-abajo
CONNECTION_STRING=Server=db;Database=BD_CosechaClima;User Id=sa;Password=la-misma-clave-de-arriba;TrustServerCertificate=True;
JWT_SECRET_KEY=cualquier-string-largo-random-de-desarrollo
```

>  **La contraseña de SQL Server tiene una política de complejidad real.** Tiene que tener mínimo 8 caracteres **y combinar al menos 3 de estas 4 categorías**: mayúsculas, minúsculas, dígitos, símbolos. Una contraseña larga pero de una sola categoría **falla igual** y se cae el contenedor `db` con `Login failed for user 'sa'` en el arranque.

El resto de las claves (`JWT_ISSUER`, `JWT_AUDIENCE`, `JWT_DURATION_MINUTES`) ya vienen con valores razonables en `.env.example`.

>  Antes de levantar nada, es buena práctica validar el YAML sin arrancar contenedores:
> ```bash
> docker compose config
> ```
> Por si editás `docker-compose.yml`.

### Levantar todo

```bash
docker compose up --build
```

Levanta 3 contenedores en orden: **`db`** → **`db-init`** → **`api`** (hacia `http://localhost:8080`).

### Confirmar que levantó bien

```bash
curl http://localhost:8080/health
```
Esperado: `200 OK` con `Healthy`.

## Opción B — Ejecutar localmente sin Docker

### 1. Levantar solo SQL Server

```bash
docker run -e "ACCEPT_EULA=Y" -e "MSSQL_SA_PASSWORD=tu-password-aqui" \
  -p 1433:1433 --name cosechaclima-db-local \
  -d mcr.microsoft.com/mssql/server:2022-latest
```

### 2. Correr los scripts

Con la extensión de SQL Server de VS Code o cualquier cliente, conectate a `localhost,1433`, usuario `sa`, y corré en orden `Scripts/BD-CosechaClima.sql` y `Scripts/seed.sql`.

### 3. Configurar la API

Sin `docker-compose.yml` inyectando nada, hace falta configurar de otra forma. Dos opciones:

**Recomendada — `dotnet user-secrets`:**
```bash
cd backend/WebApi
dotnet user-secrets init
dotnet user-secrets set "ConnectionStrings:BD_CosechaClima" "Server=localhost,1433;Database=BD_CosechaClima;User Id=sa;Password=aqui-la-password;TrustServerCertificate=True;"
dotnet user-secrets set "Jwt:SecretKey" "cualquier-string-largo-random-de-desarrollo-xd"
```

**Alternativa — editar `appsettings.Development.json`** . No dejes tu contraseña real commiteada — este archivo no está en `.gitignore`.

### 4. Correr la API

```bash
cd backend/WebApi
dotnet run
```
Levanta en `http://localhost:5013` (perfil `http`) o `https://localhost:7257` (perfil `https`) — **no** en el `8080` que usa Docker.

## Variables y claves de configuración

| Clave | Docker (`.env`) | Local (`appsettings.Development.json` / user-secrets) | Obligatoria |
|---|---|---|---|
| `ConnectionStrings:BD_CosechaClima` | `CONNECTION_STRING` | sí | Sí |
| `Jwt:SecretKey` | `JWT_SECRET_KEY` | sí | Sí |
| `Jwt:Issuer` / `Audience` / `DurationMinutes` | ya tienen default | ya tienen default | No |
| `AdminSeed:Telefono` / `Pin` / `Nombre` | `ADMIN_SEED_*` | sí | No — crea un admin automático si se completa (8 dígitos / 4 dígitos) |
| `Cors:AllowedOrigins` | `CORS_ALLOWED_ORIGIN` | sí | No |

## Cómo conseguir un usuario Admin

**Automático (recomendado):** completá `ADMIN_SEED_TELEFONO`/`ADMIN_SEED_PIN` (8 y 4 dígitos). Al arrancar, si ese usuario no existe, se crea con rol Admin; si existe pero no es Admin, se le otorga el rol. No hay ningún endpoint HTTP para volverse Admin — es deliberado, para que nadie se autopromueva. Un valor con formato inválido se ignora con un warning en el log.

**Manual:** registrá un usuario normal por `POST /api/auth/register` y otorgale el rol directo en la base:
```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Telefono = '12345678';
```

Con el token de ese usuario:
```bash
curl -X POST http://localhost:8080/api/reglas/sembrar -H "Authorization: Bearer <TOKEN_ADMIN>"
curl -X POST http://localhost:8080/api/reglas/aplicar-contenido-preliminar -H "Authorization: Bearer <TOKEN_ADMIN>"
```

## Swagger y autenticación

Abrí `/swagger`, hacé login por `POST /api/auth/login`, copiá el `token`, y usá el botón **Authorize** (arriba a la derecha) pegando `Bearer <token>` — se aplica automáticamente a todos los endpoints protegidos.

## CORS

Configurable por `Cors:AllowedOrigins` — lista de orígenes exactos permitidos (ej. `http://localhost:5173`). Sin configurar, ningún origen web puede pegarle a la API.

## Endpoints disponibles

| Controlador | Ruta base | Responsabilidad |
|---|---|---|
| `UsuarioController` | `/api/auth` | Registro y autenticación |
| `CatalogoController` | `/api/catalogos` | Cultivos, tipos de suelo, eventos climáticos, etapas fenológicas |
| `ParcelaController` | `/api/parcelas` | Gestión de parcelas del productor |
| `ClimaController` | `/api/clima` | Consulta y guardado de datos climáticos |
| `UmbralConfiguracionController` | `/api/umbrales` | Umbrales de riesgo por usuario |
| `MotorDecisionesController` | `/api/motor` | Cálculo del semáforo de riesgo |
| `ReglaDecisionController` | `/api/reglas` | Administración del árbol de reglas (rol Admin) |
| `BitacoraController` | `/api/logs` | Bitácora de campo del productor |


## Comandos necesarios al ejecutar los contenedores

```bash
docker compose logs -f # logs de todos los servicios
docker compose logs -f api # logs solo de la api
docker compose build api && docker compose up -d api # reconstruir solo la api
docker compose ps # estado de los contenedores
docker compose exec api /bin/bash # entrar a una terminal del contenedor
docker compose down -v # bajar todo y borrar el volumen de datos
```

## Estructura del proyecto

```
backend/
├── CosechaClima.sln
├── docker-compose.yml
├── Dockerfile
├── .env.example
├── WebApi/
│   ├── Program.cs
│   ├── appsettings.json
│   ├── appsettings.Development.json
│   ├── Controllers/
│   └── Dto/
├── WebApi.Models/
├── Services/
│   ├── WebApi.Interface/
│   └── WebApi.Implementation/
└── Scripts/
    ├── BD-CosechaClima.sql
    ├── seed.sql
    └── reglas-preliminares-completas.json
```

## Problemas comunes

| Síntoma | Causa probable |
|---|---|
| `db` sale con "Login failed for user 'sa'" / password validation failed | `DB_SA_PASSWORD` no cumple la política de complejidad (min. 8 caracteres, 3 de 4 categorías) |
| `docker compose config` tira un error de parseo | YAML mal indentado — revisá que `api:` tenga 2 espacios y sus propiedades 4, igual que `db:`/`db-init:` |
| El contenedor `api` se reinicia en loop | Revisá `docker compose logs api` — si es un error de SQL sobre `Telefono`/truncado, `AdminSeed` tiene un valor con formato inválido |
| `401 Unauthorized` en todos los endpoints protegidos desde Swagger | No pegaste el token en el botón "Authorize", o falta el prefijo `Bearer ` |
| `GET /api/umbrales/mios` da `404` | Esperado — el usuario todavía no configuró umbrales |
| `POST /api/motor/semaforo` da `404` con "no hay datos climaticos" | Llamá `POST /api/clima/actualizar/{parcelaId}` primero |
| `POST /api/clima/actualizar/{parcelaId}` da `503` | Revisá conectividad del contenedor a internet: `docker compose exec api curl -v https://api.open-meteo.com` |
| Un frontend web no puede pegarle a la API | Falta agregar su origen exacto a `Cors:AllowedOrigins` |

---

Nota sobre secretos: `backend/.env` nunca debe compartirse ni subirse a ningún lado. Si comprimís la carpeta para compartirla, excluilo explícitamente:
```bash
zip -r CosechaClima.zip CosechaClima -x "*.env" -x "*/bin/*" -x "*/obj/*"
```