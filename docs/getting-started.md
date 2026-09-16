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

Editar `.env` con valores propios (ver comentarios en `.env.example` para guia detallada de cada variable).

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

## Que levanta `compose.yaml`

| Contenedor | Descripcion | Orden |
|---|---|---|
| `cosechaclima-db` | SQL Server 2022 | Primero (con healthcheck) |
| `cosechaclima-db-init` | Ejecuta esquema SQL y seed de catalogos | Segundo (espera a que db este healthy) |
| `cosechaclima-api` | API ASP.NET Core 10 en http://localhost:8080 | Tercero (espera a que db-init termine) |

> [!NOTE]
> El archivo `compose.yaml` esta en la **raiz del proyecto**, no dentro de `/backend`. Todas las variables se leen del `.env` en la raiz.

## Primer uso de la API

### 1. Registrar un usuario

```bash
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"nombre": "Juan Perez", "telefono": "88887777", "pin": "1234"}'
```

### 2. Iniciar sesion

```bash
curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"telefono": "88887777", "pin": "1234"}'
```

Copiar el `token` de la respuesta.

### 3. Usar el token en endpoints protegidos

```bash
curl http://localhost:8080/api/parcelas/mias \
  -H "Authorization: Bearer <token>"
```

## Swagger

Abrir `http://localhost:8080/swagger` en el navegador. Usar el boton **Authorize** (arriba a la derecha) para pegar `Bearer <token>` y probar los endpoints protegidos interactivamente.

## Desarrollo local sin Docker

Ver [backend/README.md](../backend/README.md) para instrucciones de ejecucion local con `dotnet run`.

## App movil Flutter

Ver [mobile/README.md](../mobile/README.md) para instrucciones de instalacion, configuracion de entorno con `--dart-define`, y compilacion.

## Siguientes pasos

- [api-reference.md](./api-reference.md) -- referencia completa de todos los endpoints.
- [architecture.md](./architecture.md) -- arquitectura del sistema.
- [security.md](./security.md) -- decisiones de seguridad.
- [changelog.md](./changelog.md) -- historial de cambios.
