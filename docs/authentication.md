# Authentication

CosechaClima usa autenticacion **JWT Bearer**. Una cuenta se crea con **correo + contrasena** o con **Google**, y ambas terminan en el mismo token. Ademas, parte de la API es **publica** para que un usuario pueda ver el clima de su zona sin cuenta (modo invitado). Este documento explica el flujo completo para cualquiera que necesite consumir la API.

## Flujo resumido

```
Con correo:   POST /api/auth/register   -> crea la cuenta y devuelve el token
              POST /api/auth/login      -> devuelve el token

Con Google:   POST /api/auth/google     -> valida el ID Token, crea o vincula la cuenta y devuelve el token

Despues:      cada request protegido    -> header Authorization: Bearer <token>
```

Los tres endpoints devuelven la misma estructura ([respuesta de login](#respuesta-de-login)). Registrarse ya deja la sesion iniciada: no hace falta un `login` posterior.

## Que es publico y que requiere sesion

| Area | Endpoints | Acceso |
|---|---|---|
| Autenticacion | `POST /api/auth/register`, `/login`, `/google` | Publico (con rate limit) |
| Pronostico por coordenadas | `GET /api/clima/pronostico` | Publico |
| Catalogos | `GET /api/catalogos/*` | Publico |
| Health check | `GET /health` | Publico |
| Parcelas, umbrales, clima de una parcela, semaforo, bitacora | `/api/parcelas`, `/api/umbrales`, `/api/clima/actualizar/{id}`, `/api/motor`, `/api/logs` | JWT |
| Administracion del arbol de reglas | `/api/reglas` | JWT + rol `Admin` |

Todo endpoint nuevo nace **protegido**: solo se abre con `[AllowAnonymous]` de forma explicita y con una justificacion en el codigo.

## 1. Registro con correo

```
POST /api/auth/register
Content-Type: application/json

{ "nombre": "Juan Perez", "email": "juan@example.com", "password": "una-clave-larga" }
```

Validacion:

| Campo | Regla |
|---|---|
| `nombre` | requerido, max 100 caracteres |
| `email` | requerido, formato de correo valido, max 256 caracteres |
| `password` | requerida, entre 8 y 128 caracteres |

El correo se **normaliza a minusculas** antes de guardarse, asi que `Ana@x.com` y `ana@x.com` son la misma cuenta. La contrasena no exige mezcla de simbolos: se prioriza la longitud (OWASP Authentication Cheat Sheet, NIST SP 800-63B).

Respuesta `200`: [respuesta de login](#respuesta-de-login). Si el correo ya existe: `409` con `{ "mensaje": "ya existe una cuenta con este correo" }`.

## 2. Login con correo

```
POST /api/auth/login
Content-Type: application/json

{ "email": "juan@example.com", "password": "una-clave-larga" }
```

Respuesta `200`: [respuesta de login](#respuesta-de-login).

Respuesta `401` con `{ "mensaje": "correo o contrasena incorrectos" }`. El mensaje es **deliberadamente el mismo** para "el correo no existe", "contrasena incorrecta", "cuenta desactivada" y "la cuenta es solo de Google": distinguirlos permitiria a un atacante averiguar que correos estan registrados.

**Rate limit:** maximo 5 intentos por minuto en cada endpoint de `/api/auth/*` (ventana deslizante por IP). Pasado el limite, responde `429 Too Many Requests`.

## 3. Login con Google

```
POST /api/auth/google
Content-Type: application/json

{ "idToken": "<ID Token que entrega el SDK de Google Sign-In>" }
```

```
App Flutter --(1) Google Sign-In--> Google
App Flutter <--(2) idToken--------- Google
App Flutter --(3) POST /api/auth/google { idToken }--> API
API         --(4) valida firma, emisor, expiracion, audiencia y email verificado--> claves publicas de Google
App Flutter <--(5) { token, nombre, email, fotoUrl, esAdmin }-- API
```

El backend **nunca confia en lo que diga la app**: valida el ID Token con la libreria oficial `Google.Apis.Auth` (gratuita, no requiere Firebase ni ningun plan de pago). Se verifica:

- La **firma** contra las claves publicas de Google.
- El **emisor** y la **expiracion**.
- La **audiencia** (`aud`): debe ser uno de los Client IDs configurados en `GoogleAuth:ClientIds` (`GOOGLE_CLIENT_ID_ANDROID`, `_IOS` y `_WEB`). Un token emitido para otra app se rechaza.
- Que el **correo este verificado** por Google.

Si algo falla: `401` con `{ "mensaje": "no se pudo validar la cuenta de Google" }`. Si la cuenta existe pero esta desactivada: `401` con `{ "mensaje": "esta cuenta esta desactivada" }`.

> [!IMPORTANT]
> Si no hay ningun Client ID configurado, el endpoint responde `401` y el motivo queda en el log de la API (`GoogleAuth:ClientIds no esta configurado`). Ver [google-sign-in-setup.md](./google-sign-in-setup.md).

### Como se resuelve la cuenta

| Caso | Que pasa |
|---|---|
| El `sub` (UID) de Google ya esta registrado | Entra a esa cuenta y actualiza nombre y foto. Se busca por UID, no por correo: el UID no cambia aunque la persona cambie su correo de Google. |
| No hay UID, pero existe una cuenta de **correo** con el mismo email | Se **vinculan** ambas identidades a la misma fila. La persona puede seguir entrando con su contrasena o con Google. |
| No existe ni UID ni correo | Se crea una cuenta nueva con proveedor Google, sin contrasena. |

Una cuenta creada solo con Google **no tiene contrasena local**: intentar `POST /api/auth/login` con su correo responde `401`.

## Respuesta de login

Comun a `register`, `login` y `google`:

```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "nombre": "Juan Perez",
  "email": "juan@example.com",
  "fotoUrl": null,
  "esAdmin": false
}
```

| Campo | Descripcion |
|---|---|
| `token` | JWT a enviar en `Authorization: Bearer` |
| `nombre` | Nombre a mostrar |
| `email` | Correo de la cuenta (en minusculas) |
| `fotoUrl` | URL del avatar de Google; `null` en cuentas de correo |
| `esAdmin` | Informativo para la UI. La autorizacion real la decide el servidor con el claim `Role`, nunca este campo. |

## 4. Usar el token

Todo endpoint protegido requiere el header:

```
Authorization: Bearer <token>
```

El token expira a las **24 horas** (configurable via `JWT_DURATION_MINUTES`). Vencido o ausente, cualquier endpoint protegido responde `401 Unauthorized`. La app movil reacciona a ese `401` cerrando la sesion y volviendo al modo publico.

## Que contiene el token (claims)

| Claim | Origen | Proposito |
|---|---|---|
| `NameIdentifier` | `Usuario.Id` | Identifica al usuario en cada request -- base del control de ownership |
| `Email` | `Usuario.Email` | Informativo (reemplaza al antiguo claim `MobilePhone`) |
| `Name` | `Usuario.Nombre` | Informativo |
| `Role` | Solo si `Usuario.EsAdmin == true` | Habilita endpoints administrativos (`Authorize(Roles = "Admin")`) |
| `Jti` | GUID generado en cada login | Unicidad de token, prevencion de replay attacks |

## Seguridad de las contrasenas

- Se hashean con **PBKDF2-HMAC-SHA256, 600.000 iteraciones** y un salt aleatorio de 16 bytes por usuario (recomendacion vigente de la OWASP Password Storage Cheat Sheet).
- La comparacion usa `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.
- La contrasena en texto plano nunca llega a la base de datos, y en las cuentas de Google no existe: la administra Google.

## Ownership: por que casi ningun endpoint pide un `usuarioId`

La API nunca confia en un id de usuario que venga en la URL o en el body para decidir de quien son los datos -- siempre lo deriva del claim `NameIdentifier` del token. Los endpoints de "listar mis cosas" usan rutas como `/mias` en vez de `/usuario/{id}`: no existe la posibilidad de pedir los datos de otro usuario cambiando un numero.

Ver [security.md](./security.md) para el detalle completo de este diseno.

## Rol de administrador

Ciertos endpoints (sembrar y aplicar contenido del arbol de reglas) requieren `[Authorize(Roles = "Admin")]`. No existe ningun endpoint publico para auto-promoverse a administrador -- es una decision de diseno intencional.

Para otorgar el rol la primera vez:

```sql
UPDATE Usuarios SET EsAdmin = 1 WHERE Email = '<correo en minusculas>';
```

El usuario debe volver a iniciar sesion despues de este cambio -- el claim `Role` se graba en el token al momento del login, no se relee dinamicamente en cada request.

**Alternativa automatica:** configurar `ADMIN_SEED_EMAIL` y `ADMIN_SEED_PASSWORD` (y opcionalmente `ADMIN_SEED_NOMBRE`) en el `.env` para que el sistema cree el usuario admin al arrancar. El correo debe ser valido y la contrasena tener al menos 8 caracteres; si no, el seed se omite con una advertencia en el log. Si el correo ya existe y no es admin, se le otorga el rol.

## Errores comunes

| Codigo | Causa | Solucion |
|---|---|---|
| `401` en cualquier endpoint protegido | Falta el header, o el token expiro | Volver a hacer login |
| `401` en login | Correo o contrasena incorrectos, cuenta desactivada, o cuenta solo de Google | Mensaje intencionalmente generico; probar "Continuar con Google" |
| `401` en `/api/auth/google` | ID Token invalido, expirado, de otra app, correo sin verificar, o Client IDs sin configurar en el backend | Revisar los Client IDs y el log de la API |
| `400` en register/login | Correo con formato invalido, o contrasena de menos de 8 caracteres | Corregir el body |
| `403` en cualquier endpoint | El recurso no pertenece al usuario del token | Indica un bug si aparece en uso normal |
| `409` en register | Ya existe una cuenta con ese correo | Iniciar sesion en vez de registrarse |
| `429` en `/api/auth/*` | Mas de 5 intentos en un minuto | Esperar antes de reintentar |