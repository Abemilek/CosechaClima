# Getting Started

Cómo levantar el backend de CosechaClima desde cero, en cualquier máquina del equipo.

## Requisitos

- Docker y Docker Compose
- (Opcional, solo si vas a tocar código C# fuera de Docker) SDK de .NET 10

## Levantar el proyecto

```bash
git clone https://github.com/Abemilek/CosechaClima.git
cd CosechaClima/backend
cp .env.example .env
```

Abrí `.env` y completá tus propios valores locales (contraseña de SQL Server, clave secreta de JWT). Nunca subas este archivo con valores reales — ya está excluido en `.gitignore`.

```bash
docker compose up --build
```

Esto levanta dos contenedores: `db` (SQL Server 2022) y `api` (la aplicación .NET). El esquema y los catálogos base se aplican automáticamente al iniciar por primera vez.

La API queda disponible en:
- **Swagger (documentación interactiva):** `http://localhost:8080/swagger`
- **Health check:** `http://localhost:8080/health`

## Primeros pasos después de levantar el proyecto

El árbol de reglas de decisión no viene poblado por defecto — hay que sembrarlo una sola vez, y necesita un usuario administrador:

```bash
# 1. Registrar un usuario
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nombre":"Admin","telefono":"88880000","pin":"0000"}'

# 2. Otorgarle rol de administrador (paso manual, una sola vez)
#    conectate a la base y corré:
#    UPDATE Usuarios SET EsAdmin = 1 WHERE Telefono = '88880000';

# 3. Iniciar sesion con ese usuario para obtener un token con rol Admin
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"telefono":"88880000","pin":"0000"}'

# 4. Sembrar el arbol de reglas (con el token del paso 3)
curl -X POST http://localhost:8080/api/reglas/sembrar \
  -H "Authorization: Bearer <token>"

curl -X POST http://localhost:8080/api/reglas/aplicar-contenido-preliminar \
  -H "Authorization: Bearer <token>"
```

A partir de acá, cualquier usuario nuevo que se registre ya puede usar el flujo completo de la app.

## Probar desde un celular físico (no el emulador)

`localhost` solo funciona en la misma máquina donde corre Docker. Para un celular real en la misma red wifi, usá la IP local de esa laptop:

```bash
# Linux/Mac
ip addr show | grep "inet " | grep -v 127.0.0.1

# Windows
ipconfig
```

Y usá `http://<esa-ip>:8080` como base URL en la app.

## Siguiente lectura

- [`architecture.md`](./architecture.md) — cómo está organizado el backend por dentro.
- [`authentication.md`](./authentication.md) — cómo funciona el login y el token.
- [`api-reference.md`](./api-reference.md) — referencia completa de endpoints.
- [`mobile-integration-guide.md`](./mobile-integration-guide.md) — guía práctica para el equipo de Flutter.
