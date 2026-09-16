# CosechaClima API -- Referencia tecnica

> Ver tambien: [authentication.md](./authentication.md) para el detalle del flujo de login, y [error-handling.md](./error-handling.md) para el catalogo completo de codigos de error.

Documentacion completa de todos los endpoints. Complementa a Swagger (`/swagger`) -- Swagger es la fuente de verdad en vivo, este documento explica el por que y el flujo interno de cada endpoint.

**Base URL (Docker):** `http://localhost:8080`
**Base URL (local sin Docker):** `http://localhost:5013`

---

## Convenciones generales

### Autenticacion

Todos los endpoints, salvo los marcados como **Publico**, requieren el header:

```
Authorization: Bearer <token>
```

El token se obtiene de `POST /api/auth/login`, expira en 24 horas (configurable) y contiene un claim `Jti` para unicidad. Si falta o expiro, el endpoint devuelve `401`.

### Formato de errores

Todos los errores siguen el estandar RFC 7807 (`ProblemDetails`):

```json
{ "status": 400, "title": "Descripcion del error", "instance": "/api/ruta" }
```

### Codigos de estado

| Codigo | Significado |
|---|---|
| `200` | Exito |
| `400` | Body invalido o referencia a catalogo inexistente |
| `401` | Falta el token, o no es valido/expiro |
| `403` | Token valido, pero el recurso no pertenece al usuario autenticado |
| `404` | El recurso no existe, o falta un paso previo del flujo de negocio |
| `409` | Recurso duplicado |
| `429` | Rate limiting excedido |
| `503` | Servicio externo no disponible y sin dato de respaldo |

### Ownership

Ningun endpoint acepta un `usuarioId` como parametro. Siempre se deriva del claim `NameIdentifier` del token. Las rutas usan `/mias` o `/mios` en vez de `/usuario/{id}`.

---

## Indice

1. [Autenticacion](#1-autenticacion)
2. [Parcelas](#2-parcelas)
3. [Umbrales de configuracion](#3-umbrales-de-configuracion)
4. [Clima](#4-clima)
5. [Motor de decisiones](#5-motor-de-decisiones)
6. [Bitacora de campo](#6-bitacora-de-campo)
7. [Reglas de decision (administracion)](#7-reglas-de-decision-administracion)
8. [Catalogos](#8-catalogos)
9. [Health check](#9-health-check)

---

## 1. Autenticacion

**Controlador:** `UsuarioController` -- **Ruta base:** `/api/auth` -- **Acceso:** Publico
**Rate limit:** politica `auth` (5 peticiones/minuto por IP, ventana deslizante)

### POST /api/auth/register

Crea una cuenta nueva. Genera un salt aleatorio, calcula el hash PBKDF2 del PIN, y guarda solo el hash.

**Request body (`RegisterDto`):**

| Campo | Tipo | Requerido | Validacion |
|---|---|---|---|
| `nombre` | string | Si | max 100 caracteres |
| `telefono` | string | Si | exactamente 8 digitos (`^\d{8}$`) |
| `pin` | string | Si | exactamente 4 digitos (`^\d{4}$`) |

```json
{ "nombre": "Juan Perez", "telefono": "88887777", "pin": "1234" }
```

**Respuestas:**

| Codigo | Cuerpo |
|---|---|
| `200` | `{ "id": 1, "mensaje": "usuario registrado correctamente" }` |
| `409` | Telefono ya registrado |
| `429` | Rate limit excedido |

### POST /api/auth/login

Autentica al usuario por telefono + PIN. Si coincide, genera un JWT firmado con HMAC-SHA256 conteniendo claims de identidad, rol y Jti.

**Request body (`LoginDto`):**

| Campo | Tipo | Requerido | Validacion |
|---|---|---|---|
| `telefono` | string | Si | exactamente 8 digitos |
| `pin` | string | Si | exactamente 4 digitos |

```json
{ "telefono": "88887777", "pin": "1234" }
```

**Respuestas:**

| Codigo | Cuerpo |
|---|---|
| `200` | `{ "token": "eyJhbGci...", "nombre": "Juan Perez" }` |
| `401` | Telefono o PIN incorrectos (mensaje generico deliberado) |
| `429` | Rate limit excedido |

---

## 2. Parcelas

**Controlador:** `ParcelaController` -- **Ruta base:** `/api/parcelas` -- **Acceso:** JWT requerido

### POST /api/parcelas

Registra una parcela nueva. El `usuarioId` se asigna automaticamente desde el token.

**Request body (`ParcelaRequestDto`):**

| Campo | Tipo | Requerido | Validacion |
|---|---|---|---|
| `cultivoId` | int | Si | debe existir en catalogo |
| `etapaFenologicaId` | int? | No | si se envia, debe existir |
| `tipoSueloId` | int | Si | debe existir en catalogo |
| `fechaSiembra` | date | Si | formato `YYYY-MM-DD` |
| `areaMzs` | decimal | Si | 0.01 - 99999.99 |
| `latitud` | decimal? | No | -90 a 90 |
| `longitud` | decimal? | No | -180 a 180 |
| `municipio` | string? | No | max 100 |
| `comunidad` | string? | No | max 100 |

**Respuesta:** `200` -> `{ "id": 3 }`

### PUT /api/parcelas/{id}

Actualiza campos parciales de una parcela. Verifica ownership.

**Request body (`ParcelaUpdateRequestDto`):**

| Campo | Tipo | Requerido | Validacion |
|---|---|---|---|
| `latitud` | decimal? | No | -90 a 90 |
| `longitud` | decimal? | No | -180 a 180 |
| `areaMzs` | decimal? | No | 0.01 - 99999.99 |
| `municipio` | string? | No | max 100 |
| `comunidad` | string? | No | max 100 |

**Respuestas:** `200` `{ "actualizada": true }` / `400` sin datos / `403` / `404`

### GET /api/parcelas/{id}

Devuelve una parcela especifica. Verifica ownership.

**Respuestas:** `200` objeto `Parcela` / `403` / `404`

### GET /api/parcelas/mias

Lista todas las parcelas del usuario autenticado.

**Respuesta:** `200` array de `Parcela` (puede ser `[]`)

### PUT /api/parcelas/{id}/etapa/{etapaId}

Actualiza la etapa fenologica de una parcela. Verifica ownership y existencia de la etapa.

**Respuestas:** `200` / `400` etapa no existe / `403` / `404`

### DELETE /api/parcelas/{id}

Elimina una parcela. Verifica ownership.

**Respuestas:** `200` / `403` / `404`

---

## 3. Umbrales de configuracion

**Controlador:** `UmbralConfiguracionController` -- **Ruta base:** `/api/umbrales` -- **Acceso:** JWT requerido

### POST /api/umbrales

Crea o actualiza (upsert) los umbrales de riesgo del usuario. Cada usuario tiene un unico registro de umbrales.

**Request body (`UmbralRequestDto`):**

| Campo | Tipo | Requerido | Default | Validacion |
|---|---|---|---|---|
| `lluviaIntensaMm` | int | No | 100 | 0 - 1000 |
| `vientoFuerteKmh` | int | No | 40 | 0 - 300 |
| `caniculaDias` | int | No | 7 | 1 - 60 |
| `variedadCultivo` | string | No | "Criollo" | max 50 |
| `tieneRiego` | bool | No | false | -- |
| `horarioSms` | time | Si | -- | formato `HH:mm` |

**Respuesta:** `200` -> `{ "id": 1 }`

### GET /api/umbrales/mios

**Respuestas:** `200` objeto `UmbralConfiguracion` / `404` (usuario no ha configurado umbrales -- Flutter debe interpretar como "mostrar pantalla de configuracion inicial")

---

## 4. Clima

**Controlador:** `ClimaController` -- **Ruta base:** `/api/clima` -- **Acceso:** JWT requerido

### POST /api/clima/actualizar/{parcelaId}

**Flujo interno:**

1. Busca la parcela por id y verifica ownership.
2. Verifica que tenga `latitud`/`longitud` cargadas.
3. Si existe dato del dia actual con menos de 6 horas de antiguedad, lo retorna del cache.
4. Si no, llama a Open-Meteo con las coordenadas de la parcela.
5. Si Open-Meteo falla, busca el ultimo dato guardado como respaldo.

**Respuestas:**

| Codigo | Significado |
|---|---|
| `200` | Objeto `DatosClimaticos` |
| `400` | La parcela no tiene coordenadas registradas |
| `403` | La parcela no es del usuario autenticado |
| `404` | La parcela no existe |
| `503` | Open-Meteo no respondio y no hay datos previos guardados |

**Modelo `DatosClimaticos`:**

| Campo | Tipo |
|---|---|
| `id` | int |
| `parcelaId` | int |
| `fecha` | datetime |
| `temperaturaMedia` | decimal? |
| `temperaturaMax` | decimal? |
| `temperaturaMin` | decimal? |
| `precipitacion` | decimal? |
| `humedadRelativa` | decimal? |
| `vientoVelocidad` | decimal? |
| `radiacionSolar` | decimal? |
| `fuenteClima` | string |
| `fechaDescarga` | datetime |

> [!NOTE]
> Este endpoint debe llamarse **antes** de pedir el semaforo (seccion 5). El motor de decisiones necesita datos climaticos guardados para calcular.

---

## 5. Motor de decisiones

**Controlador:** `MotorDecisionesController` -- **Ruta base:** `/api/motor` -- **Acceso:** JWT requerido
**Rate limit:** politica `motor`

### POST /api/motor/semaforo

**Request body (`SemaforoRequestDto`):**

| Campo | Tipo | Requerido |
|---|---|---|
| `parcelaId` | int | Si |

```json
{ "parcelaId": 5 }
```

**Flujo interno:**

1. Verifica ownership de la parcela.
2. Determina la etapa fenologica (usa la asignada, o la calcula desde la fecha de siembra).
3. Busca los umbrales configurados por el usuario.
4. Busca el dato climatico mas reciente de la parcela.
5. Evalua **todos los eventos climaticos activos simultaneamente**:

| Evento | Condicion de activacion |
|---|---|
| Riesgo de helada | `TemperaturaMin <= 2` |
| Lluvia intensa | `Precipitacion >= umbrales.LluviaIntensaMm` |
| Viento fuerte | `VientoVelocidad >= umbrales.VientoFuerteKmh` |
| Temperatura extrema | `TemperaturaMax >= 35` |
| Canicula | N dias consecutivos sin precipitacion (`umbrales.CaniculaDias`) |
| Sin riesgo | Ninguno de los anteriores |

6. Para cada evento activo, busca la regla en el arbol de 216 combinaciones (evento x cultivo x etapa x suelo).
7. Selecciona la regla con el **nivel de riesgo mas alto** (Alto > Medio > Bajo).
8. Guarda o actualiza la alerta del dia.

**Respuesta (`SemaforoDto`):**

```json
{
  "nivelRiesgo": "Alto",
  "descripcionAlerta": "PRELIMINAR: el exceso de agua satura el suelo...",
  "acciones": ["Revisar drenajes", "Evitar encharcamiento", "Monitorear pudricion"],
  "fecha": "2026-09-16"
}
```

**Errores:** `403` (no es del usuario) / `404` (con mensaje descriptivo en `title`: parcela no existe, sin etapa, sin umbrales, sin datos climaticos, o sin regla para la combinacion)

> [!NOTE]
> Un `404` de este endpoint no siempre es un error de la app. Puede ser un caso de negocio real (ej. "todavia no configuraste umbrales"). Leer el campo `title` del `ProblemDetails` para mostrar un mensaje util.

---

## 6. Bitacora de campo

**Controlador:** `BitacoraController` -- **Ruta base:** `/api/logs` -- **Acceso:** JWT requerido

### POST /api/logs

Registra una entrada de bitacora. Verifica ownership de la parcela.

**Request body (`BitacoraRequestDto`):**

| Campo | Tipo | Requerido | Validacion |
|---|---|---|---|
| `parcelaId` | int | Si | debe pertenecer al usuario |
| `fecha` | date | Si | -- |
| `eventoClimaticoId` | int | Si | -- |
| `nivelRiesgo` | string | Si | max 20 |
| `accion1Texto` | string | Si | max 500 |
| `accion2Texto` | string | Si | max 500 |
| `accion3Texto` | string | Si | max 500 |
| `notas` | string? | No | max 2000 |

Las 3 acciones nacen como "no completadas". Solo se marcan con el endpoint siguiente.

**Respuesta:** `200` -> `{ "id": 5 }`

### GET /api/logs/mias

Lista entradas de bitacora del usuario, ordenadas por fecha descendente.

**Respuesta:** `200` -> array de `BitacoraCampo`

### PUT /api/logs/{entradaId}/action/{numeroAccion}

Marca una de las 3 acciones como completada. `numeroAccion` debe ser `1`, `2` o `3`. Verifica ownership.

**Respuestas:** `200` / `403` / `404`

### GET /api/logs/mias/summary

Genera un texto plano con las ultimas entradas de bitacora, pensado para compartir por WhatsApp/SMS.

**Respuesta:** `200` -> `{ "summary": "16/09: riesgo Alto - [x] Revisar drenajes\n15/09: ..." }`

---

## 7. Reglas de decision (administracion)

**Controlador:** `ReglaDecisionController` -- **Ruta base:** `/api/reglas` -- **Acceso:** JWT + Rol `Admin`

> [!WARNING]
> Estos endpoints son para configuracion inicial del backend. No deben aparecer en la app movil.

### GET /api/reglas

Devuelve las 216 reglas del arbol de decision completo.

**Respuesta:** `200` -> array de `ReglaDecision`

### POST /api/reglas/sembrar

Genera las 216 combinaciones si no existen. Operacion idempotente.

**Respuesta:** `200` -> `{ "mensaje": "reglas placeholder generadas o ya existian" }`

### POST /api/reglas/aplicar-contenido-preliminar

Aplica el contenido agronomico real desde `Scripts/reglas-preliminares-completas.json` usando `OPENJSON` en un unico batch. Operacion idempotente.

**Respuesta:** `200` -> `{ "message": "contenido preliminar aplicado reglas representativas" }`

---

## 8. Catalogos

**Controlador:** `CatalogoController` -- **Ruta base:** `/api/catalogos` -- **Acceso:** JWT requerido

| Endpoint | Respuesta |
|---|---|
| `GET /api/catalogos/cultivos` | `List<Cultivo>` (id, nombre, nombreCientifico) |
| `GET /api/catalogos/tipos-suelo` | `List<TipoSuelo>` (id, nombre, descripcion) |
| `GET /api/catalogos/eventos-climaticos` | `List<EventoClimatico>` (id, nombre, descripcion) |
| `GET /api/catalogos/etapas-fenologicas` | `List<EtapaFenologica>` (id, nombre, descripcion, diasDesdeSiembra) |

---

## 9. Health check

**Ruta:** `/health` -- **Acceso:** Publico

Verifica que la API pueda conectarse a la base de datos.

| Codigo | Significado |
|---|---|
| `200` | `Healthy` -- todo operativo |
| `503` | Base de datos no responde |

> [!NOTE]
> Endpoint de infraestructura. Docker lo usa para healthcheck de contenedores. La app movil no deberia llamarlo en el flujo normal.
