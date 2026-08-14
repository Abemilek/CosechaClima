# CosechaClima API — Referencia técnica

> Ver también: [`authentication.md`](./authentication.md) para el detalle del flujo de login, y [`error-handling.md`](./error-handling.md) para el catálogo completo de códigos de error.

Documentación completa de todos los endpoints, (motor de decisiones, autorización por ownership, DTOs de validación, rate limiting, Open-Meteo). Complementa a Swagger (`/swagger`) — Swagger es la fuente de verdad *en vivo*, este documento explica el **por qué** y el **flujo interno** de cada endpoint, que Swagger no muestra.

**Base URL (local):** `http://localhost:8080`
**Base URL (Docker en red local):** `http://<IP de la laptop>:8080`

## Convenciones generales

### Autenticación
Todos los endpoints, salvo los marcados como **Público**, requieren un header:
```
Authorization: Bearer <token>
```
El token se obtiene de `POST /api/usuarios/login` y expira en 24 horas (configurable). Si falta o expiró, el endpoint devuelve `401`.

### Formato de errores
Todos los errores (salvo validación automática de modelo) siguen el estándar `ProblemDetails` (RFC 7807):
```json
{ "status": 400, "title": "Descripción del error", "instance": "/api/ruta" }
```

### Códigos de estado usados en toda la API

| Código | Significado en esta API |
|---|---|
| `200` | Éxito |
| `400` | Body inválido (falta un campo requerido, o no cumple una regla de validación) |
| `401` | Falta el token, o no es válido/expiró |
| `403` | Token válido, pero el recurso pedido no pertenece al usuario autenticado |
| `404` | El recurso no existe |
| `429` | Demasiadas peticiones en poco tiempo (rate limiting, solo en `/register` y `/login`) |
| `503` | Un servicio externo (Open-Meteo) no respondió y no hay dato de respaldo |

### Ownership (importante para entender el diseño)
Ningún endpoint acepta un `usuarioId` como parámetro para decidir de quién son los datos — **siempre se deriva del token**. Los endpoints de "listar mis cosas" usan rutas como `/mias` en vez de `/usuario/{id}`, precisamente para que no exista la posibilidad de pedir los datos de otro usuario cambiando un número en la URL.

---

## Índice

1. [Usuarios y autenticación](#1-usuarios-y-autenticación)
2. [Parcelas](#2-parcelas)
3. [Umbrales de configuración](#3-umbrales-de-configuración)
4. [Clima](#4-clima)
5. [Motor de decisiones](#5-motor-de-decisiones)
6. [Bitácora de campo](#6-bitácora-de-campo)
7. [Reglas de decisión (administración)](#7-reglas-de-decisión-administración)
8. [Health check](#8-health-check)

---

## 1. Usuarios y autenticación

Controlador: `UsuarioController` — Ruta base: `/api/usuarios` — **Público** (sin token)
Rate limit: máx. 5 peticiones/minuto por endpoint (ventana deslizante) — devuelve `429` si se excede.

### `POST /api/usuarios/register`

**Qué hace:** crea una cuenta nueva. Internamente genera un `salt` aleatorio, calcula `SHA256(pin + salt)`, y guarda **solo el hash** — el PIN en texto plano nunca llega a la base de datos.

**Request body:**
| Campo | Tipo | Requerido | Validación |
|---|---|---|---|
| `nombre` | string | Sí | máx. 100 caracteres |
| `telefono` | string | Sí | exactamente 8 dígitos numéricos |
| `pin` | string | Sí | exactamente 4 dígitos numéricos |

```json
{ "nombre": "Juan Perez", "telefono": "88887777", "pin": "1234" }
```

**Respuestas:**
- `200 OK` → `{ "id": 1, "mensaje": "Usuario registrado correctamente" }`
- `400` → violación de validación (ej. teléfono con letras)
- `409 Conflict` → el teléfono ya está registrado

### `POST /api/usuarios/login`

**Qué hace:** busca al usuario por teléfono, recalcula el hash del PIN recibido con el `salt` guardado, y compara contra el hash almacenado. Si coincide, genera un JWT firmado con expiración de 24 horas conteniendo el id, teléfono y nombre del usuario como claims.

**Request body:**
```json
{ "telefono": "88887777", "pin": "1234" }
```

**Respuestas:**
- `200 OK` → `{ "token": "eyJhbGci...", "nombre": "Juan Perez" }`
- `401` → teléfono o PIN incorrectos (mensaje deliberadamente genérico, no distingue cuál de los dos falló — evita revelar si un teléfono está registrado)

---

## 2. Parcelas

Controlador: `ParcelaController` — Ruta base: `/api/parcelas` — **Requiere token**

### `POST /api/parcelas`

**Qué hace:** registra una parcela nueva. El `usuarioId` se asigna automáticamente desde el token — cualquier valor que el cliente intente mandar para ese campo se ignora (no existe siquiera en el DTO de request).

**Request body (`ParcelaRequestDto`):**
| Campo | Tipo | Requerido | Validación |
|---|---|---|---|
| `cultivoId` | int | Sí | debe existir en el catálogo `Cultivos` |
| `etapaFenologicaId` | int? | No | puede quedar sin definir al principio |
| `tipoSueloId` | int | Sí | debe existir en el catálogo `TipoSuelo` |
| `fechaSiembra` | date | Sí | formato `YYYY-MM-DD` |
| `areaMzs` | decimal | Sí | entre 0.01 y 10000 |
| `latitud` | decimal? | No | entre -90 y 90 |
| `longitud` | decimal? | No | entre -180 y 180 |
| `municipio` | string? | No | máx. 100 caracteres |
| `comunidad` | string? | No | máx. 100 caracteres |

**Respuesta:** `200 OK` → `{ "id": 3 }`

**Nota de flujo:** si la parcela se crea sin `latitud`/`longitud`, el endpoint `POST /api/clima/actualizar/{id}` (sección 4) va a devolver `400` hasta que se actualicen — el clima no se puede consultar sin coordenadas.

### `GET /api/parcelas/{id}`

**Qué hace:** devuelve una parcela específica. Antes de responder, verifica que `parcela.UsuarioId` coincida con el usuario del token.

**Respuestas:**
- `200 OK` → objeto `Parcela` completo
- `403` → la parcela existe, pero no es del usuario autenticado
- `404` → no existe una parcela con ese id (nota: si no existe, técnicamente también podría devolver `403` según la implementación — tratalos igual desde Flutter, en ambos casos significa "no tenés acceso a esto")

### `GET /api/parcelas/mias`

**Qué hace:** lista todas las parcelas del usuario autenticado. No recibe ningún parámetro — el usuario se deriva 100% del token.

**Respuesta:** `200 OK` → array de objetos `Parcela` (puede ser `[]` si no tiene ninguna todavía).

### `PUT /api/parcelas/{id}/etapa/{etapaId}`

**Qué hace:** actualiza la etapa fenológica de una parcela (por ejemplo, cuando el cultivo pasa de "Desarrollo vegetativo" a "Floración"). Verifica ownership antes de actualizar.

**Respuestas:** `200 OK` (actualizado) / `403` (no es tuya) / `404` (no existe)

**Nota de flujo:** este es el endpoint que Flutter debería llamar cuando el usuario marca manualmente que su cultivo avanzó de etapa — el motor de decisiones usa este valor para seleccionar la regla correcta, así que si nunca se actualiza, el semáforo va a seguir evaluando contra la etapa con la que se creó la parcela.

### `DELETE /api/parcelas/{id}`

**Qué hace:** elimina una parcela. Verifica ownership antes de borrar.

**Respuestas:** `200 OK` / `403` / `404`

---

## 3. Umbrales de configuración

Controlador: `UmbralConfiguracionController` — Ruta base: `/api/umbrales` — **Requiere token**

### `POST /api/umbrales`

**Qué hace:** crea o actualiza (upsert) los umbrales de riesgo del usuario autenticado — cada usuario tiene un único registro de umbrales (no uno por parcela). El motor de decisiones compara los datos climáticos del día contra estos valores para determinar qué evento climático está activo.

**Request body (`UmbralRequestDto`):**
| Campo | Tipo | Requerido | Default | Validación |
|---|---|---|---|---|
| `lluviaIntensaMm` | int | No | 100 | 0 - 1000 |
| `vientoFuerteKmh` | int | No | 40 | 0 - 300 |
| `caniculaDias` | int | No | 7 | 1 - 60 |
| `variedadCultivo` | string | No | "Criollo" | máx. 50 caracteres |
| `tieneRiego` | bool | No | false | — |
| `horarioSms` | time | Sí | — | formato `HH:mm` |

**Respuesta:** `200 OK` → `{ "id": 1 }`

### `GET /api/umbrales/mios`

**Respuestas:** `200 OK` → objeto `UmbralConfiguracion` / `404` → el usuario todavía no configuró umbrales (Flutter debería interpretar esto como "mostrar la pantalla de configuración inicial", no como un error)

---

## 4. Clima

Controlador: `ClimaController` — Ruta base: `/api/clima` — **Requiere token**

### `POST /api/clima/actualizar/{parcelaId}`

**Qué hace — flujo interno paso a paso:**
1. Busca la parcela por id y verifica ownership.
2. Verifica que tenga `latitud`/`longitud` cargadas.
3. Llama a la API de Open-Meteo con esas coordenadas, pidiendo el día anterior, hoy y 2 días de pronóstico.
4. Si Open-Meteo responde bien, guarda el dato del día actual en `DatosClimaticos` y lo devuelve.
5. Si Open-Meteo falla (sin internet, timeout de 10s, error del servicio), busca el último dato climático ya guardado para esa parcela (hasta 3 días atrás) y lo devuelve como respaldo, sin lanzar error.

**Respuestas:**
- `200 OK` → objeto `DatosClimaticos` (con `temperaturaMax`, `temperaturaMin`, `precipitacion`, `vientoVelocidad`, `fuenteNASA`)
- `400` → la parcela no tiene coordenadas registradas
- `403` → la parcela no es del usuario autenticado
- `404` → la parcela no existe
- `503` → Open-Meteo no respondió **y** tampoco hay ningún dato previo guardado (caso raro, típicamente solo en la primerísima consulta de una parcela recién creada sin conexión)

**Nota de flujo para Flutter:** este endpoint hay que llamarlo **antes** de pedir el semáforo (sección 5) — el motor de decisiones necesita un dato climático guardado para poder calcular algo. Una buena práctica de UX es encadenar ambas llamadas automáticamente cuando el usuario entra a la pantalla de una parcela, mostrando un loading mientras tanto.

---

## 5. Motor de decisiones

Controlador: `MotorDecisionesController` — Ruta base: `/api/motor` — **Requiere token**

### `GET /api/motor/semaforo?parcelaId={id}`

**Qué hace — flujo interno paso a paso:**
1. Verifica ownership de la parcela.
2. Busca los umbrales configurados por el usuario.
3. Busca el dato climático más reciente guardado para esa parcela (el que trajo el endpoint de la sección 4).
4. Compara los valores del clima contra los umbrales para determinar cuál de los 6 eventos climáticos está activo (lluvia intensa, canícula, viento fuerte, temperatura extrema, riesgo de helada, o "sin riesgo" si nada supera el umbral). La canícula se evalúa contra varios días consecutivos sin lluvia, no solo el día actual.
5. Busca en el árbol de 180 reglas la combinación exacta de evento × cultivo × etapa fenológica × tipo de suelo.
6. Guarda (o actualiza, si ya existe una para el día de hoy) el resultado en la tabla `Alertas`.
7. Devuelve el semáforo.

**Query params:** `parcelaId` (int, requerido)

**Respuesta (`200 OK`, `SemaforoDto`):**
```json
{
  "nivelRiesgo": "Alto",
  "descripcionAlerta": "PRELIMINAR: el exceso de agua satura el suelo...",
  "acciones": ["Revisar drenajes", "Evitar encharcamiento", "Monitorear pudricion"],
  "fecha": "2026-08-08"
}
```

**Errores:**
- `403` → la parcela no es del usuario
- `404` → puede significar varias cosas distintas, todas con mensaje descriptivo en el body: la parcela no existe, no tiene etapa fenológica asignada, el usuario no configuró umbrales, no hay datos climáticos guardados, o no existe una regla para esa combinación exacta (esto último puede pasar en las 175 combinaciones que todavía están en `'PENDIENTE'`)

**Nota importante para Flutter:** un `404` acá no siempre significa "error de la app" — puede ser un caso de negocio real y esperado (ej. "todavía no configuraste umbrales"). Conviene leer el mensaje del `title` en el `ProblemDetails` y mostrarle al usuario un mensaje útil según el caso, no un error genérico.

---

## 6. Bitácora de campo

Controlador: `BitacoraController` — Ruta base: `/api/logs` — **Requiere token**

### `POST /api/logs`

**Qué hace:** registra que el productor tomó nota del semáforo de un día. Verifica que la `parcelaId` enviada pertenezca al usuario antes de guardar.

**Request body (`BitacoraRequestDto`):**
| Campo | Tipo | Requerido |
|---|---|---|
| `parcelaId` | int | Sí |
| `fecha` | date | Sí |
| `eventoClimaticoId` | int | Sí |
| `nivelRiesgo` | string | Sí (máx. 20) |
| `accion1Texto`, `accion2Texto`, `accion3Texto` | string | Sí (máx. 500 cada uno) |
| `notas` | string? | No (máx. 2000) |

Nota: las 3 acciones nacen siempre como "no completadas" — no hay forma de crear una entrada que ya nazca marcada, eso solo se hace con el endpoint siguiente.

**Respuesta:** `200 OK` → `{ "id": 5 }`

### `GET /api/logs/mias`

**Respuesta:** `200 OK` → array de entradas de bitácora del usuario, ordenadas por fecha descendente.

### `PUT /api/logs/{entradaId}/action/{numeroAccion}`

**Qué hace:** marca una de las 3 acciones como completada. `numeroAccion` debe ser `1`, `2` o `3`. Verifica que la entrada pertenezca al usuario antes de modificarla.

**Respuestas:** `200 OK` / `403` / `404`

### `GET /api/logs/mias/summary`

**Qué hace:** arma un texto plano con las últimas 5 entradas de bitácora, pensado para compartir por WhatsApp/SMS.

**Respuesta:** `200 OK` → `{ "summary": "08/08: riesgo Alto - [x] Revisar drenajes\n07/08: ..." }`

---

## 7. Reglas de decisión (administración)

Controlador: `ReglaDecisionController` — Ruta base: `/api/reglas` — **Requiere token** (endpoints administrativos, no hay rol separado todavía — cualquier usuario logueado puede llamarlos, es una limitación conocida y documentada)

### `GET /api/reglas`
Devuelve las 180 reglas del árbol de decisión completo. Útil para depurar por qué el semáforo devolvió lo que devolvió.

### `POST /api/reglas/sembrar`
Genera las 180 combinaciones si todavía no existen (operación idempotente — correrlo dos veces no duplica nada). Se llama **una sola vez**, al levantar la base de datos por primera vez.

### `POST /api/reglas/aplicar-contenido-preliminar`
Aplica el contenido agronómico real a las 5 reglas representativas ya investigadas. También idempotente.

**Nota para Flutter:** estos 3 endpoints no forman parte del flujo normal de la app — son de configuración inicial del backend, no deberían aparecer en ninguna pantalla de la app móvil.

---

## 8. Health check

### `GET /health` — **Público**

**Qué hace:** verifica que la API pueda conectarse a la base de datos en este momento.

**Respuestas:**
- `200 OK` con cuerpo `Healthy` → todo bien
- `503` → la base de datos no responde

**Nota:** no es un endpoint de negocio, es para monitoreo (Docker lo usa para saber si tiene que reiniciar el contenedor). Flutter no debería llamarlo nunca en el flujo normal de la app.
