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
> `DB_SA_PASSWORD` debe cumplir la politica de complejidad de SQL Server: minimo 8 caracteres combinando al menos 3 de 4 categorias (mayusculas, minusculas, digitos, simbolos).

> [!WARNING]
> SQL Server solo aplica `DB_SA_PASSWORD` **la primera vez** que crea el volumen. Si la cambias despues, el contenedor `db` queda `unhealthy` con `Login failed for user 'sa'`. Ademas, los scripts SQL solo crean lo que falta: si el esquema cambio y ya existe un volumen viejo, hay que migrarlo (ver [authentication.md](./authentication.md#migracion-desde-telefono--pin)) o recrearlo. En desarrollo se resuelve todo con `docker compose down -v && docker compose up --build`, que **borra los datos**.

## Que levanta `compose.yaml`

| Contenedor | Descripcion | Orden |
|---|---|---|
| `cosechaclima-db` | SQL Server 2022 | Primero (con healthcheck) |
| `cosechaclima-db-init` | Ejecuta esquema SQL y seed de catalogos | Segundo (espera a que db este healthy) |
| `cosechaclima-api` | API ASP.NET Core 10 en http://localhost:8080 | Tercero (espera a que db-init termine) |

> [!NOTE]
> El archivo `compose.yaml` esta en la **raiz del proyecto**, no dentro de `/backend`. Todas las variables se leen del `.env` en la raiz.

## Primer uso de la API

### 0. Sin cuenta (modo invitado)

Hay endpoints publicos que no piden token:

```bash
# Catalogos
curl http://localhost:8080/api/catalogos/cultivos

# Pronostico de 5 dias por coordenadas
curl "http://localhost:8080/api/clima/pronostico?latitud=11.85&longitud=-86.199"
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