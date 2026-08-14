# CosechaClima — Guía de endpoints para la integracion de la aplicacion

> Ver también: [`authentication.md`](./authentication.md) (detalle del token JWT) y [`api-reference.md`](./api-reference.md) (referencia exhaustiva de cada endpoint, con el flujo interno explicado).

Esto es lo único que necesitás saber para conectar la app con el backend: qué endpoint llamar, para qué sirve en la app, y en qué orden. No hace falta entender nada de lo que pasa "detrás" (base de datos, C#, etc.) — la API es una caja negra que recibe JSON y devuelve JSON.

## Cómo se comunican un backend y un frontend

El backend expone endpoints, el frontend los consume. Ninguno de los dos necesita saber cómo está construido el otro por dentro — solo necesitan ponerse de acuerdo en **el contrato**: qué URL, qué se manda, qué se recibe. Eso es justo lo que describe este documento. Cuando algo cambie de este contrato, backend avisa antes de mergear — así nunca se rompe algo sin que el otro lado se entere.

**Base URL:** `http://localhost:8080` (emulador) o `http://IP-de-la-laptop:8080` (celular físico, misma wifi)
**Explorar en vivo:** `http://localhost:8080/swagger`

## Autenticación — leelo una sola vez, aplica a todo lo demás

Después de iniciar sesión, la API te da un `token`. Guardalo (con `flutter_secure_storage`) y mandalo en **todos** los demás endpoints, en este header:

```
Authorization: Bearer <token>
```

Sin token válido, la API responde `401` → mandá al usuario a login. El token vence a las 24 horas.

---

## Los endpoints

### Registro y login (sin token)

| Endpoint | Qué hace en la app |
|---|---|
| `POST /api/auth/register` | Crea la cuenta del productor (nombre, teléfono, PIN de 4 dígitos). Pantalla: registro. |
| `POST /api/auth/login` | Verifica teléfono+PIN y devuelve el `token`. Pantalla: login. Llamalo cada vez que el usuario abre sesión. |

### Parcela (requiere token)

| Endpoint | Qué hace en la app |
|---|---|
| `POST /api/parcelas` | Registra una parcela nueva: cultivo, suelo, etapa, coordenadas GPS. Pantalla: "agregar parcela". |
| `GET /api/parcelas/mias` | Lista las parcelas del usuario logueado. Pantalla: inicio / selector de parcelas. |
| `GET /api/parcelas/{id}` | Trae el detalle de una parcela específica. Pantalla: detalle de parcela. |
| `PUT /api/parcelas/{id}/etapa/{etapaId}` | Actualiza en qué etapa de crecimiento está el cultivo. Llamalo cuando el usuario indique que su cultivo avanzó de etapa. |
| `DELETE /api/parcelas/{id}` | Elimina una parcela. |

### Umbrales (requiere token)

| Endpoint | Qué hace en la app |
|---|---|
| `POST /api/umbrales` | Guarda a partir de qué cantidad de lluvia/viento el usuario quiere ser alertado. Pantalla: configuración (puede tener valores por defecto, es opcional para el usuario tocarla). |
| `GET /api/umbrales/mios` | Trae la configuración actual del usuario. |

### Clima y semáforo — el corazón de la app (requiere token)

| Endpoint | Qué hace en la app |
|---|---|
| `POST /api/clima/actualizar/{parcelaId}` | Trae el clima real y actual de esa parcela (usando sus coordenadas). Llamalo **antes** del siguiente endpoint. |
| `GET /api/motor/semaforo?parcelaId={id}` | Calcula el semáforo de riesgo (Alto/Medio/Bajo/Sin riesgo) + 3 acciones recomendadas. Pantalla principal de la app — esto es lo que el productor vino a ver. |

### Bitácora de campo (requiere token)

| Endpoint | Qué hace en la app |
|---|---|
| `POST /api/logs` | Registra que el usuario tomó nota del semáforo de un día. Pantalla: "guardar en bitácora" (después de ver el semáforo). |
| `GET /api/logs/mias` | Lista el historial de bitácora del usuario. Pantalla: historial. |
| `PUT /api/logs/{entradaId}/action/{numeroAccion}` | Marca una de las 3 acciones recomendadas como completada (`numeroAccion` = 1, 2 o 3). Pantalla: checkbox en el detalle de una entrada. |
| `GET /api/logs/mias/summary` | Devuelve un texto listo para compartir por WhatsApp con el resumen de los últimos días. Botón: "compartir". |

---

## El flujo completo, con ejemplo

Así es como un usuario nuevo recorre la app la primera vez — seguí este orden:

```
1. Registrarse           → POST /api/auth/register
     { "nombre": "Juan Perez", "telefono": "88887777", "pin": "1234" }

2. Iniciar sesion         → POST /api/auth/login
     { "telefono": "88887777", "pin": "1234" }
     ← devuelve el token. Guardalo.

3. Crear su parcela       → POST /api/parcelas
     { "cultivoId": 1, "tipoSueloId": 1, "fechaSiembra": "2026-05-01",
       "areaMzs": 2.5, "latitud": 11.89, "longitud": -86.19 }
     ← devuelve el id de la parcela. Guardalo.

4. Configurar umbrales    → POST /api/umbrales
     (opcional, puede usar los valores por defecto)

5. Ver el semaforo:
   5a. Traer clima real   → POST /api/clima/actualizar/{parcelaId}
   5b. Calcular semaforo  → GET  /api/motor/semaforo?parcelaId={id}
     ← devuelve nivelRiesgo + 3 acciones. Esta es la pantalla principal.

6. Guardar en bitacora    → POST /api/logs
     (con los mismos datos que devolvio el paso 5b)

7. Marcar accion hecha    → PUT /api/logs/{entradaId}/action/1
```

Los pasos 5a y 5b siempre van juntos — cuando el usuario entra a ver una parcela, llamalos uno después del otro, con un loading en el medio.

## Errores

Todos los errores vienen así:
```json
{ "status": 400, "title": "mensaje explicando que paso" }
```

| Código | Qué hacer |
|---|---|
| `401` | Mandar al usuario a login (no hay token, o venció) |
| `403` | No debería pasar nunca (estás pidiendo datos que no son tuyos) — si aparece, es un bug, avisá |
| `404` | Falta un paso previo del flujo, o el dato no existe — leé el `title` |
| `429` | Demasiados intentos de login seguidos, mostrar "esperá un momento" |

## Si algo no funciona

Probalo primero en Swagger (`/swagger`). Si ahí también falla, es tema de backend, no tuyo. Si en Swagger funciona pero en Flutter no, revisá el header `Authorization` y la URL base.
