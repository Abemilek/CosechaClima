# CosechaClima — Backend

API REST para **CosechaClima**, un sistema de alerta temprana climática para pequeños productores de maíz y frijol en Carazo, Nicaragua. Cruza datos climáticos con la etapa fenológica del cultivo del usuario y devuelve recomendaciones priorizadas mediante un sistema de semáforo (verde / amarillo / rojo).

[![.NET](https://img.shields.io/badge/.NET-10.0-512BD4?logo=dotnet)](https://dotnet.microsoft.com/)
[![SQL Server](https://img.shields.io/badge/SQL%20Server-2022-CC2927?logo=microsoftsqlserver&logoColor=white)](https://www.microsoft.com/sql-server)
[![Docker](https://img.shields.io/badge/Docker-Compose-2496ED?logo=docker&logoColor=white)](https://www.docker.com/)
[![License](https://img.shields.io/badge/status-en%20desarrollo-yellow)]()

---

## Tabla de contenidos

- [Arquitectura](#arquitectura)
- [Stack técnico](#stack-técnico)
- [Requisitos previos](#requisitos-previos)
- [Cómo ejecutarlo con Docker (recomendado)](#cómo-ejecutarlo-con-docker-recomendado)
- [Cómo ejecutarlo localmente sin Docker](#cómo-ejecutarlo-localmente-sin-docker)
- [Variables de entorno](#variables-de-entorno)
- [Endpoints disponibles](#endpoints-disponibles)
- [Comandos útiles](#comandos-útiles)
- [Estructura del proyecto](#estructura-del-proyecto)

---

## Arquitectura

El backend está organizado en capas, siguiendo la convención estándar de proyectos .NET:

```
CosechaClima.sln
│
├── WebApi.Models/              Entidades del dominio
│
├── Services/
│   ├── WebApi.Interface/       Contratos de los servicios
│   └── WebApi.Implementation/  Lógica de negocio y acceso a datos (ADO.NET)
│
└── WebApi/                     Punto de entrada: controladores, Program.cs
```

La API se comunica con SQL Server mediante ADO.NET puro (`Microsoft.Data.SqlClient`), sin ORM, y usa autenticación por JWT.

---

## Stack técnico

| Componente | Tecnología |
|---|---|
| Framework | ASP.NET Core (.NET 10) |
| Base de datos | SQL Server 2022 |
| Acceso a datos | ADO.NET (`Microsoft.Data.SqlClient`) |
| Autenticación | JWT Bearer |
| Documentación de API | Swagger / OpenAPI |
| Contenedores | Docker + Docker Compose |

---

## Requisitos previos

Para ejecutar el proyecto con Docker (la forma recomendada) solo necesitas:

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) o Docker Engine + Docker Compose (Linux)

Para ejecutarlo sin Docker, en su lugar necesitas:

- [.NET SDK 10.0](https://dotnet.microsoft.com/download)
- Una instancia de SQL Server accesible (local o remota)

---

## Cómo ejecutarlo con Docker (recomendado)

Este es el método soportado oficialmente: levanta la API y SQL Server juntos, ya conectados entre sí, con la base de datos inicializada automáticamente.

**1. Clona el repositorio y entra a la carpeta del backend:**

```bash
git clone https://github.com/Abemilek/CosechaClima.git
cd CosechaClima/backend
```

**2. Crea tu archivo de variables de entorno a partir de la plantilla:**

```bash
cp .env.example .env
```

Abre `.env` y reemplaza los valores de ejemplo por los tuyos (contraseña de base de datos y clave JWT). No uses los valores de ejemplo en ningún entorno compartido.

**3. Levanta todo el sistema:**

```bash
docker compose up --build
```

Esto construye la imagen de la API, levanta un contenedor de SQL Server, y ejecuta automáticamente los scripts de creación de esquema y datos semilla la primera vez que se corre.

**4. Verifica que todo está arriba:**

Abre en tu navegador:

```
http://localhost:8080/swagger
```

Ahí puedes ver y probar todos los endpoints disponibles de forma interactiva.

**5. Para detener el sistema:**

```bash
docker compose down
```

Esto detiene los contenedores sin borrar los datos de la base de datos (persisten en un volumen). Si necesitas reiniciar la base de datos completamente desde cero:

```bash
docker compose down -v
```

---

## Cómo ejecutarlo localmente sin Docker

Si prefieres correr la API directamente con el SDK de .NET, sin contenedores:

**1. Restaura las dependencias:**

```bash
cd backend
dotnet restore
```

**2. Configura tu cadena de conexión y clave JWT** en `WebApi/appsettings.Development.json`:

```json
{
  "ConnectionStrings": {
    "BD_CosechaClima": "Server=localhost;Database=BD_CosechaClima;User Id=sa;Password=<tu_password>;TrustServerCertificate=True;"
  },
  "Jwt": {
    "Issuer": "CosechaClimaAPI",
    "Audience": "CosechaClimaApp",
    "SecretKey": "<tu_clave_secreta>",
    "DurationMinutes": 1440
  }
}
```

Este archivo está en `.gitignore` para evitar subir credenciales reales por accidente — verifica que así se mantenga.

**3. Crea el esquema y los datos iniciales** ejecutando, en orden, los scripts de `Scripts/` contra tu instancia de SQL Server:

```
Scripts/BD-CosechaClima.sql
Scripts/seed.sql
```

**4. Ejecuta la API:**

```bash
dotnet run --project WebApi
```

---

## Variables de entorno

Estas son las variables que necesita el archivo `.env` (ver `.env.example` para la plantilla completa):

| Variable | Descripción |
|---|---|
| `DB_SA_PASSWORD` | Contraseña del usuario `sa` de SQL Server |
| `CONNECTION_STRING` | Cadena de conexión completa que usa la API para conectarse a la base de datos |
| `JWT_ISSUER` | Emisor de los tokens JWT |
| `JWT_AUDIENCE` | Audiencia esperada de los tokens JWT |
| `JWT_SECRET_KEY` | Clave usada para firmar los tokens JWT |
| `JWT_DURATION_MINUTES` | Duración de validez de cada token, en minutos |

`DB_SA_PASSWORD` y la contraseña dentro de `CONNECTION_STRING` deben coincidir exactamente.

---

## Endpoints disponibles

La documentación interactiva completa está disponible en `/swagger` una vez que el proyecto está corriendo. A alto nivel, los controladores disponibles son:

| Controlador | Responsabilidad |
|---|---|
| `UsuarioController` | Registro y autenticación de usuarios |
| `ParcelaController` | Gestión de parcelas del productor |
| `ClimaController` | Consulta de datos climáticos |
| `UmbralConfiguracionController` | Configuración de umbrales de riesgo |
| `MotorDecisionesController` | Motor de reglas de decisión (semáforo) |
| `ReglaDecisionController` | Gestión de reglas de decisión |
| `BitacoraController` | Bitácora de campo del productor |

---

## Comandos útiles

```bash
# Ver logs en tiempo real de todos los servicios
docker compose logs -f

# Ver logs solo de la API
docker compose logs -f api

# Reconstruir solo la API tras cambios de código
docker compose build api && docker compose up -d api

# Ver el estado de los contenedores
docker compose ps

# Entrar a una terminal dentro del contenedor de la API
docker compose exec api /bin/bash
```

---

## Estructura del proyecto

```
backend/
├── CosechaClima.sln
├── Dockerfile
├── docker-compose.yml
├── .env.example
├── Scripts/
│   ├── BD-CosechaClima.sql
│   └── seed.sql
├── WebApi/
│   ├── Controllers/
│   ├── Dto/
│   ├── Program.cs
│   └── appsettings.json
├── WebApi.Models/
└── Services/
    ├── WebApi.Interface/
    └── WebApi.Implementation/
```

---

Proyecto desarrollado como parte del evento de aplicaciones móviles de CUR-Carazo, UNAN Managua. En desarrollo activo.