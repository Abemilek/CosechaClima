# Authentication

CosechaClima usa autenticacion **JWT Bearer** con login por telefono + PIN. Este documento explica el flujo completo para cualquiera que necesite consumir la API.

## Flujo resumido

```
1. POST /api/auth/register  -> crea la cuenta
2. POST /api/auth/login     -> devuelve un token
3. Cada request siguiente   -> header Authorization: Bearer <token>
```

## 1. Registro

```
POST /api/auth/register
Content-Type: application/json

{ "nombre": "Juan Perez", "telefono": "88887777", "pin": "1234" }
```

Validacion: `telefono` exactamente 8 digitos, `pin` exactamente 4 digitos. El PIN nunca se guarda en texto plano -- se transforma con PBKDF2 + un salt aleatorio individual por usuario antes de guardarse.

## 2. Login

```
POST /api/auth/login
Content-Type: application/json

{ "telefono": "88887777", "pin": "1234" }
```

Respuesta:

```json
{ "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...", "nombre": "Juan Perez" }
```

**Rate limit:** maximo 5 intentos por minuto en este endpoint (ventana deslizante por IP). Pasado el limite, responde `429 Too Many Requests`.

## 3. Usar el token

Todo endpoint protegido requiere el header:

```
Authorization: Bearer <token>
```

El token expira a las **24 horas** (configurable via `JWT_DURATION_MINUTES`). Vencido o ausente, cualquier endpoint protegido responde `401 Unauthorized`.

## Que contiene el token (claims)

| Claim | Origen | Proposito |
|---|---|---|
| `NameIdentifier` | `Usuario.Id` | Identifica al usuario en cada request -- base del control de ownership |
| `MobilePhone` | `Usuario.Telefono` | Informativo |
| `Name` | `Usuario.Nombre` | Informativo |
| `Role` | Solo si `Usuario.EsAdmin == true` | Habilita endpoints administrativos (`Authorize(Roles = "Admin")`) |
| `Jti` | GUID generado en cada login | Unicidad de token, prevencion de replay attacks |

## Seguridad del PIN

- El PIN se hashea con PBKDF2 + salt aleatorio individual por usuario.
- La comparacion del hash usa `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.
- El PIN en texto plano nunca llega a la base de datos.

## Ownership: por que casi ningun endpoint pide un `usuarioId`

La API nunca confia en un id de usuario que venga en la URL o en el body para decidir de quien son los datos -- siempre lo deriva del claim `NameIdentifier` del token. Los endpoints de "listar mis cosas" usan rutas como `/mias` en vez de `/usuario/{id}`: no existe la posibilidad de pedir los datos de otro usuario cambiando un numero.

Ver [security.md](./security.md) para el detalle completo de este diseno.

## Rol de administrador

Ciertos endpoints (sembrar y aplicar contenido del arbol de reglas) requieren `[Authorize(Roles = "Admin")]`. No existe ningun endpoint publico para auto-promoverse a administrador -- es una decision de diseno intencional.

Para otorgar el rol la primera vez:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Telefono = '<telefono>';
```

El usuario debe volver a iniciar sesion despues de este cambio -- el claim `Role` se graba en el token al momento del login, no se relee dinamicamente en cada request.

**Alternativa automatica:** configurar `ADMIN_SEED_TELEFONO` y `ADMIN_SEED_PIN` en el `.env` para que el sistema cree el usuario admin al arrancar.

## Errores comunes

| Codigo | Causa | Solucion |
|---|---|---|
| `401` en cualquier endpoint protegido | Falta el header, o el token expiro | Volver a hacer login |
| `401` en login | Telefono o PIN incorrectos | Mensaje intencionalmente generico |
| `403` en cualquier endpoint | El recurso no pertenece al usuario del token | Indica un bug si aparece en uso normal |
| `429` en login/register | Mas de 5 intentos en un minuto | Esperar antes de reintentar |
