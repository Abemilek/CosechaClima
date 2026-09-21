# Security

Decisiones de seguridad, hallazgos resueltos y politicas de proteccion de la API CosechaClima. Alineado con [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x00-header/).

## Autenticacion

- **JWT Bearer** con firmado HMAC-SHA256.
- Clave secreta minimo 32 caracteres (256 bits), validada al arranque: la API no levanta si falta, es mas corta o conserva el texto de relleno de `.env.example`.
- Claim `Jti` (JWT ID) generado como GUID en cada login para unicidad de token y prevencion de replay attacks.
- Expiracion configurable (default: 24 horas).
- **Correo + contrasena:** la contrasena se almacena como hash PBKDF2-HMAC-SHA256 (600.000 iteraciones) con salt aleatorio individual por usuario. Minimo 8 caracteres, sin exigir mezcla de simbolos (OWASP Authentication Cheat Sheet, NIST SP 800-63B). La contrasena en texto plano nunca se persiste.
- Comparacion de hash usando `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.
- **Google Sign-In:** el ID Token se valida siempre en el servidor con `Google.Apis.Auth` (firma, emisor, expiracion, audiencia contra `GoogleAuth:ClientIds` y correo verificado). El backend nunca confia en el correo que declare la app. Las cuentas de Google no tienen contrasena local.
- Correos normalizados a minusculas; `Email` y `GoogleUid` son unicos (este ultimo con indice unico filtrado).
- Respuesta de login **generica** (`correo o contrasena incorrectos`) para no revelar que correos estan registrados, ni si la cuenta es solo de Google o esta desactivada.

## Autorizacion

- **Ownership-based access control:** todos los recursos (parcelas, umbrales, bitacora, clima) verifican que el `UsuarioId` del recurso coincida con el claim `NameIdentifier` del token JWT. Nunca se acepta un `usuarioId` como parametro de URL o body.
- **Rol Admin:** separado para operaciones administrativas (sembrado y aplicacion de reglas). No existe endpoint HTTP para auto-promoverse -- otorgado exclusivamente via seed de base de datos o SQL directo.
- `[Authorize]` aplicado a nivel de clase en todos los controladores de negocio.
- `[Authorize(Roles = "Admin")]` en los 3 endpoints de `ReglaDecisionController`.
- **Endpoints publicos** (`[AllowAnonymous]`), cada uno abierto de forma explicita: `/api/auth/*`, `GET /api/clima/pronostico`, `GET /api/catalogos/*` y `/health`. Ninguno expone datos de un usuario: el pronostico publico no se asocia a parcelas ni se persiste, y los catalogos son datos de referencia agricola.

## Rate Limiting

| Politica | Tipo | Limite | Endpoints protegidos |
|---|---|---|---|
| `auth` | Ventana deslizante | 5 peticiones/minuto por IP | `POST /api/auth/register`, `POST /api/auth/login`, `POST /api/auth/google` |
| `motor` | Aplicada al controlador | Previene abuso computacional | `POST /api/motor/semaforo` |

Respuesta al exceder el limite: `429 Too Many Requests`.

> [!WARNING]
> La politica `auth` cuenta por la IP de origen de la conexion. Detras de un proxy inverso o un tunel (ngrok, etc.) todos los clientes llegan con la misma IP, y los 5 intentos por minuto pasan a ser **compartidos por todos los usuarios**. Si la API se expone asi, hay que configurar `ForwardedHeaders` para leer la IP real del cliente.

## Validacion de entrada

- DataAnnotations declarativas en todos los DTOs de request (`[Required]`, `[Range]`, `[MaxLength]`, `[RegularExpression]`).
- Verificacion de existencia de claves foraneas (cultivos, suelos, etapas fenologicas) antes de operaciones de escritura.
- DTOs de request dedicados (`ParcelaRequestDto`, `BitacoraRequestDto`, `UmbralRequestDto`) reemplazando binding directo de entidades de dominio.

## Manejo de errores

- Manejador global de excepciones (`ManejadorErroresGlobal`) implementando `IExceptionHandler`.
- Todos los errores retornados como RFC 7807 `ProblemDetails`.
- Excepciones SQL traducidas a codigos HTTP apropiados (FK violation -> 400, unique constraint -> 409).
- Detalles internos de excepciones nunca expuestos al cliente -- solo logueados en servidor.

## Prevencion de inyeccion SQL

- Todas las queries usan comandos parametrizados exclusivamente (`SqlCommand` con `SqlParameter`).
- Cero concatenacion de strings en construccion de consultas SQL.
- Operaciones batch implementadas con `OPENJSON` (T-SQL nativo), no con construccion dinamica de SQL.

## Seguridad en Docker

- Imagen runtime **Alpine** (`aspnet:10.0-alpine`) con superficie de ataque minima.
- Ejecucion con **usuario no-root** en el contenedor.
- Sin utilidades de shell innecesarias (sin `curl`, sin `bash` completo).
- Healthcheck implementado con `wget` (incluido en Alpine por defecto).

## Gestion de secretos

- Todas las credenciales y claves gestionadas via variables de entorno (archivo `.env`).
- `.env` excluido de control de versiones via `.gitignore`.
- `.env.example` proporcionado con descripciones y reglas de validacion, sin valores reales.
- Cero secretos hardcodeados en el codigo fuente.

## CORS

- Restringido por lista explicita de origenes permitidos (`Cors:AllowedOrigins`).
- Sin origenes configurados, ningun origen web puede acceder a la API.
- La app movil no usa CORS.

## Entorno de ejecucion

- `ASPNETCORE_ENVIRONMENT` tiene por defecto `Production` en `compose.yaml`: Swagger queda oculto y se activa la redireccion HTTPS.
- Solo `Development` (definido explicitamente en `.env`) expone `/swagger`. No usarlo en un servidor accesible desde internet.

## Seguridad en el cliente movil (Flutter)

- Token JWT almacenado en `flutter_secure_storage` (EncryptedSharedPreferences en Android, Keychain en iOS).
- Nunca almacenado en `SharedPreferences` ni en variables de texto plano. `SharedPreferences` solo guarda datos no sensibles de la UI (nombre, correo, URL de foto e indicador de onboarding visto).
- Cierre de sesion automatico ante respuestas `401` (token expirado): la app vuelve al modo publico.
- URLs de API inyectadas via `--dart-define`, nunca hardcodeadas.
- El Client ID de Google que lleva la app **no es un secreto**; el *client secret* no se usa ni se incluye en ningun momento.
- Builds de release con `https://` obligatorio: el trafico `http://` solo esta permitido en el manifest de debug. Ver [mobile/README.md](../mobile/README.md) para la firma del APK.

## Limitaciones conocidas

Decisiones y huecos que hoy se aceptan de forma consciente; estan en el backlog (ver [changelog.md](./changelog.md)).

| Limitacion | Riesgo | Mitigacion sugerida |
|---|---|---|
| El registro por correo **no verifica** que el correo pertenezca a quien lo escribe | Alguien podria registrar el correo de otra persona con una contrasena propia. Si esa persona despues entra con Google, las cuentas se vinculan y **la contrasena del atacante seguiria valida** | Verificar el correo al registrarse, o al vincular con Google descartar la contrasena existente |
| `GET /api/clima/pronostico` es publico, sin rate limit ni cache | Cada llamada consulta Open-Meteo: un abuso podria agotar su cuota gratuita | Politica de rate limiting por IP y cache corto por coordenadas redondeadas |
| Rate limit por IP detras de proxy o tunel | Limite compartido entre todos los usuarios (ver arriba) | `ForwardedHeaders` |

## Ver tambien

- [authentication.md](./authentication.md) -- flujo detallado de login (correo y Google), modo invitado y JWT.
- [google-sign-in-setup.md](./google-sign-in-setup.md) -- configuracion de Google Sign-In.
- [error-handling.md](./error-handling.md) -- catalogo de codigos de error.
- [api-reference.md](./api-reference.md) -- referencia completa de endpoints.