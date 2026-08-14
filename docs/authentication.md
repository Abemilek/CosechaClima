# Authentication

CosechaClima usa autenticación **JWT Bearer** con login por teléfono + PIN. Este documento explica el flujo completo, para cualquiera que necesite consumir la API (frontend, pruebas manuales, otro servicio).

## Flujo resumido

```
1. POST /api/auth/register  → crea la cuenta
2. POST /api/auth/login     → devuelve un token
3. Cada request siguiente   → header Authorization: Bearer <token>
```

## 1. Registro

```
POST /api/auth/register
Content-Type: application/json

{ "nombre": "Juan Perez", "telefono": "88887777", "pin": "1234" }
```

Validación: `telefono` exactamente 8 dígitos, `pin` exactamente 4 dígitos. El PIN nunca se guarda en texto plano — se transforma con SHA-256 + un salt aleatorio individual por usuario antes de guardarse.

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

**Rate limit:** máximo 5 intentos por minuto en este endpoint (ventana deslizante). Pasado el límite, responde `429 Too Many Requests`.

## 3. Usar el token

Todo endpoint protegido requiere el header:
```
Authorization: Bearer <token>
```

El token expira a las **24 horas**. Vencido o ausente, cualquier endpoint protegido responde `401 Unauthorized`.

## Qué contiene el token (claims)

| Claim | De dónde sale | Para qué sirve |
|---|---|---|
| `NameIdentifier` | `Usuario.Id` | Identifica al usuario en cada request — es la base del control de ownership |
| `MobilePhone` | `Usuario.Telefono` | Informativo |
| `Name` | `Usuario.Nombre` | Informativo |
| `Role` | Solo si `Usuario.EsAdmin == true` | Habilita endpoints administrativos (`Authorize(Roles = "Admin")`) |

## Ownership: por qué casi ningún endpoint pide un `usuarioId`

La API nunca confía en un id de usuario que venga en la URL o en el body para decidir de quién son los datos — siempre lo deriva del claim `NameIdentifier` del token. Por eso los endpoints de "listar mis cosas" usan rutas como `/mias` en vez de `/usuario/{id}`: no existe la posibilidad de pedir los datos de otro usuario cambiando un número.

Ver [`security.md`](./security.md) para el detalle completo de este diseño.

## Rol de administrador

Ciertos endpoints (sembrar y aplicar contenido del árbol de reglas) requieren `[Authorize(Roles = "Admin")]`. No existe ningún endpoint público para auto-promoverse a administrador — es una decisión de diseño intencional. Para otorgar el rol la primera vez:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Telefono = '<telefono>';
```

El usuario debe volver a iniciar sesión después de este cambio — el claim `Role` se graba en el token al momento del login, no se relee dinámicamente en cada request.

## Errores comunes

| Código | Causa | Solución |
|---|---|---|
| `401` en cualquier endpoint protegido | Falta el header, o el token expiró | Volver a hacer login |
| `401` en login | Teléfono o PIN incorrectos | El mensaje es intencionalmente genérico, no distingue cuál de los dos falló |
| `403` en cualquier endpoint | El recurso pedido no pertenece al usuario del token | No debería pasar en uso normal de la app — indica un bug si aparece |
| `429` en login/register | Más de 5 intentos en un minuto | Esperar antes de reintentar |
