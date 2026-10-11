# Getting Started

Guia rapida para levantar el entorno completo de CosechaClima.

## Prerequisitos

- [Docker + Docker Compose](https://www.docker.com/) instalados.

## Inicio rapido

```bash
git clone https://github.com/Abemilek/CosechaClima.git
cd CosechaClima
cp .env.example .env
```

Editar `.env` con valores propios (ver comentarios en `.env.example` para guia detallada de cada variable). Lo minimo para arrancar:

| Variable | Notas |
|---|---|
| `DB_SA_PASSWORD` y `CONNECTION_STRING` | Misma contrasena en ambas |
| `JWT_SECRET_KEY` | Obligatoria, minimo 32 bytes. Generar con `openssl rand -base64 48` |
| `ASPNETCORE_ENVIRONMENT` | Poner `Development` para tener Swagger en `/swagger`; sin definirla el default es `Production` |
| `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` | Opcionales: crean el usuario administrador al arrancar |
| `GOOGLE_CLIENT_ID_*` | Opcionales: solo para "Continuar con Google" (ver [google-sign-in-setup.md](./google-sign-in-setup.md)) |

```bash
docker compose up --build -d
```

Verificar que todo esta corriendo:

```bash
curl http://localhost:8080/health
```

Esperado: `200 OK` con `Healthy`.

> [!WARNING]
> `DB_APP_PASSWORD` debe ser **exactamente la misma** contrasena que escribas dentro de `CONNECTION_STRING`. `DB_ADMIN_PASSWORD` es la del superusuario `postgres` (la API no la usa). Genera ambas con `openssl rand -base64 24`.

> [!WARNING]
> PostgreSQL solo aplica las contrasenas **la primera vez** que inicializa el volumen. Para cambiarlas despues: `ALTER ROLE cosechaclima_app PASSWORD '...'`. Las migraciones (`backend/Scripts/migrations`) se aplican solas al arrancar la API y solo ejecutan las que faltan. En desarrollo, para empezar de cero: `docker compose down -v && docker compose up --build`, que **borra los datos**.

## Que levanta `compose.yaml`

| Contenedor | Descripcion | Orden |
|---|---|---|
| `cosechaclima-db` | PostgreSQL 18; la primera vez crea el rol `cosechaclima_app` (sin privilegios de superusuario) y su base | Primero (con healthcheck) |
| `cosechaclima-api` | API ASP.NET Core 10 en http://localhost:8080; al arrancar aplica las migraciones y siembra reglas | Segundo (espera a que db este healthy) |
| `cosechaclima-adminconsole` | Admin Console en http://localhost:5174 | Tercero (espera a que la API este healthy) |

> [!NOTE]
> El archivo `compose.yaml` esta en la **raiz del proyecto**, no dentro de `/backend`. Todas las variables se leen del `.env` en la raiz.

> [!NOTE]
> Para probar el Admin Console por `http://localhost` (sin TLS) pon `AUTH_COOKIE_SECURE=false` en el `.env`; en produccion deja `true` y sirve panel y API bajo HTTPS.

## Primer uso de la API

### 0. Sin cuenta (modo invitado)

Hay endpoints publicos que no piden token:

```bash
# Catalogos
curl http://localhost:8080/api/catalogos/cultivos

# Paquete de reglas (lo que la app descarga para calcular alertas en el dispositivo)
curl -i http://localhost:8080/api/reglas/paquete
```

### 1. Registrar un usuario

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Juan Perez", "email": "juan@example.com", "password": "una-clave-larga"}'
```

La respuesta ya trae el `token`: registrarse deja la sesion iniciada.

### 2. Iniciar sesion

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email": "juan@example.com", "password": "una-clave-larga"}'
```

Copiar el `token` de la respuesta. (El login con Google lo hace la app movil; ver [google-sign-in-setup.md](./google-sign-in-setup.md).)

### 3. Usar el token en endpoints protegidos

```bash
curl http://localhost:8080/api/parcelas/mias \
  -H "Authorization: Bearer <token>"
```

## Swagger

Con `ASPNETCORE_ENVIRONMENT=Development`, abrir `http://localhost:8080/swagger` en el navegador. Usar el boton **Authorize** (arriba a la derecha) para pegar `Bearer <token>` y probar los endpoints protegidos interactivamente.

## Desarrollo local sin Docker

Ver [backend/README.md](../backend/README.md) para instrucciones de ejecucion local con `dotnet run`.

## App movil Flutter

Ver [mobile/README.md](../mobile/README.md) para instrucciones de instalacion, configuracion de entorno con `--dart-define`, y compilacion.

## Siguientes pasos

- [api-reference.md](./api-reference.md) -- referencia completa de todos los endpoints.
- [authentication.md](./authentication.md) -- login con correo y Google, modo invitado y JWT.
- [google-sign-in-setup.md](./google-sign-in-setup.md) -- configurar Google Sign-In.
- [architecture.md](./architecture.md) -- arquitectura del sistema.
- [security.md](./security.md) -- decisiones de seguridad.
- [changelog.md](./changelog.md) -- historial de cambios.