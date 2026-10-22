# Security

> [!IMPORTANT]
> Documento del **backend/stack histórico**. La app móvil v2 es 100 % local y
> no usa esta API. Para la app vigente ver [local-first.md](./local-first.md).


Decisiones de seguridad, hallazgos resueltos y politicas de proteccion de la API CosechaClima. Alineado con [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x00-header/).

## Autenticacion

- **JWT Bearer** con firmado HMAC-SHA256.
- Clave secreta minimo 32 caracteres (256 bits), validada al arranque: la API no levanta si falta, es mas corta o conserva el texto de relleno de `.env.example`.
- Claim `Jti` (JWT ID) generado como GUID en cada login para unicidad de token y prevencion de replay attacks.
- **Access token de 15 minutos** (configurable; la API avisa si superas 60) con tolerancia de reloj de 30 s, algoritmo restringido a HS256 y renovacion con refresh token (ver [Sesiones](#sesiones-y-refresh-tokens)).
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
- **Endpoints publicos** (`[AllowAnonymous]`), cada uno abierto de forma explicita: `/api/auth/*`, `GET /api/reglas/paquete`, `GET /api/catalogos/*` y `/health`. Ninguno expone datos de un usuario: el paquete de reglas y los catalogos son datos de referencia agricola (la misma informacion que viaja embebida en la app).

## Rate Limiting

| Politica | Tipo | Limite | Endpoints protegidos |
|---|---|---|---|
| `auth` | Ventana deslizante | 5 peticiones/minuto por IP | `POST /api/auth/register`, `/login`, `/google`, `/web/login` |
| `refresh` | Ventana deslizante | 30 peticiones/minuto por IP | `POST /api/auth/refresh`, `/logout`, `/web/refresh` (mas holgada: ocurre en segundo plano y varias personas pueden compartir IP por el NAT del operador) |
| `publico` | Ventana deslizante | 30 peticiones/minuto por IP | `GET /api/reglas/paquete` |
| `motor` | Por usuario | 30 peticiones/minuto | `POST /api/motor/semaforo` (legado), `PUT /api/alertas/parcela/{id}` |

Respuesta al exceder el limite: `429 Too Many Requests`.

### Detras de un proxy inverso

Las politicas por IP usan `RemoteIpAddress`. Detras de nginx, Caddy, un balanceador o un tunel esa direccion es la del proxy, y el limite pasaria a ser **global**. Por eso `Program.cs` aplica `UseForwardedHeaders` (primer middleware) leyendo `X-Forwarded-For` / `X-Forwarded-Proto` **solo si declaras de quien confiar**: `Proxy:KnownProxies` (IPs) o `Proxy:KnownNetworks` (CIDR), variables `PROXY_KNOWN_PROXY` / `PROXY_KNOWN_NETWORK`. Sin esa lista las cabeceras se ignoran, de modo que nadie puede falsear su IP para esquivar el limite (practica indicada en la documentacion de Microsoft sobre proxies y balanceadores).

## Sesiones y refresh tokens

- **Refresh token opaco** (256 bits aleatorios), de **un solo uso**: cada canje entrega uno nuevo (rotacion). En la base solo se guarda su **SHA-256** (`refresh_tokens.token_hash`); el token en claro nunca se persiste.
- **Deteccion de reutilizacion:** presentar un token ya canjeado (o revocado) revoca toda la familia (todos los tokens de ese inicio de sesion). Excepcion deliberada: si la respuesta del canje se perdio por mala conexion y el token nuevo **nunca se uso**, el cliente puede reintentar con el anterior; sin esta tolerancia, un corte de red en zona rural cerraria la sesion.
- Duracion deslizante de 30 dias con **tope absoluto de 180 dias** por inicio de sesion.
- Desactivar una cuenta revoca sus refresh tokens en la misma transaccion; un job elimina los tokens vencidos cada 6 horas.
- **App movil:** access token y refresh token en `flutter_secure_storage`. La renovacion es de una sola peticion a la vez (single-flight); solo se cierra la sesion cuando el servidor rechaza el refresh token, nunca por falta de conexion.
- **Admin Console web:** el access token vive solo en memoria (ya no en `localStorage`, donde un XSS podia leerlo) y el refresh token en la cookie `cc_refresh`: `HttpOnly`, `Secure` (configurable solo para pruebas locales), `SameSite=Strict`, `Path=/api/auth/web`. `refresh` y `logout` exigen la cabecera `X-Requested-With: cosechaclima-admin` (obliga a preflight CORS: defensa CSRF) y CORS con credenciales solo para origenes explicitos. Panel y API deben ser del mismo *sitio* (mismo dominio registrable) para que la cookie viaje.
- Respuestas de autenticacion con `Cache-Control: no-store`.

## Cabeceras y limites

- API: `X-Content-Type-Options: nosniff`, `Referrer-Policy: no-referrer`, `X-Frame-Options: DENY`, `Strict-Transport-Security` fuera de Development, y cuerpo maximo de peticion de 256 KB.
- Admin Console (nginx): `Content-Security-Policy` (scripts solo propios, `connect-src` limitado al origen y a la API, `frame-ancestors 'none'`), `nosniff`, `Referrer-Policy`, `X-Frame-Options`, `Permissions-Policy` y `server_tokens off`.

## Validacion de entrada

- DataAnnotations declarativas en todos los DTOs de request (`[Required]`, `[Range]`, `[MaxLength]`, `[RegularExpression]`).
- Verificacion de existencia de claves foraneas (cultivos, suelos, etapas fenologicas) antes de operaciones de escritura.
- DTOs de request dedicados (`ParcelaRequestDto`, `BitacoraRequestDto`, `UmbralRequestDto`) reemplazando binding directo de entidades de dominio.

## Manejo de errores

- Manejador global de excepciones (`ManejadorErroresGlobal`) implementando `IExceptionHandler`.
- Todos los errores retornados como RFC 7807 `ProblemDetails`.
- Errores de PostgreSQL traducidos por `SQLSTATE`: `23503` (FK) -> 400, `23505` (unico) -> 409, `23514` (CHECK) -> 400, y caidas transitorias de la base -> 503.
- Detalles internos de excepciones nunca expuestos al cliente -- solo logueados en servidor.

## Prevencion de inyeccion SQL

- Todas las queries usan comandos parametrizados exclusivamente (`NpgsqlCommand` con parametros).
- Los unicos fragmentos dinamicos son nombres de tabla/columna que salen de literales fijos del propio codigo (nunca de la entrada del usuario).
- Operaciones batch con `jsonb_to_recordset` (parametro `jsonb`), no con construccion dinamica de SQL.
- Restricciones `CHECK` en la base (niveles de riesgo validos, rangos de coordenadas, longitudes) como segunda barrera aunque falle la validacion de la API.

## Seguridad de la base de datos (PostgreSQL)

- La API se conecta con el rol `cosechaclima_app`: **sin** privilegios de superusuario, creacion de bases ni de roles, y duenio solo de su base. El superusuario `postgres` queda reservado para administracion.
- Puerto 5432 publicado unicamente en `127.0.0.1`.
- Fuera de la red interna de Docker usa TLS: `SSL Mode=VerifyFull` en la cadena de conexion.
- Migraciones con checksum: una migracion ya aplicada que cambie impide el arranque.
- Mas detalle en [postgresql.md](./postgresql.md).

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

- Access token y refresh token almacenados en `flutter_secure_storage` (EncryptedSharedPreferences en Android, Keychain en iOS).
- Nunca almacenado en `SharedPreferences` ni en variables de texto plano. `SharedPreferences` solo guarda datos no sensibles de la UI (nombre, correo, URL de foto e indicador de onboarding visto).
- Ante un `401` la app renueva la sesion con el refresh token; solo vuelve al modo publico si el servidor rechaza esa renovacion.
- El semaforo se calcula en el dispositivo: la ubicacion de la parcela se envia directamente a Open-Meteo (no a un servidor propio) y al servidor solo llega el evento detectado.
- URLs de API inyectadas via `--dart-define`, nunca hardcodeadas.
- El Client ID de Google que lleva la app **no es un secreto**; el *client secret* no se usa ni se incluye en ningun momento.
- Builds de release con `https://` obligatorio: el trafico `http://` solo esta permitido en el manifest de debug. Ver [mobile/README.md](../mobile/README.md) para la firma del APK.

## Limitaciones conocidas

Decisiones y huecos que hoy se aceptan de forma consciente; estan en el backlog (ver [changelog.md](./changelog.md)).

| Limitacion | Riesgo | Mitigacion sugerida |
|---|---|---|
| El registro por correo **no verifica** que el correo pertenezca a quien lo escribe | Alguien podria registrar el correo de otra persona con una contrasena propia. Si esa persona despues entra con Google, las cuentas se vinculan y **la contrasena del atacante seguiria valida** | Verificar el correo al registrarse, o al vincular con Google descartar la contrasena existente |
| Open-Meteo gratuito es solo para uso **no comercial** (con atribucion CC BY 4.0 y cuota diaria por IP) | Si CosechaClima pasa a uso comercial incumpliria sus terminos | Contratar el plan de pago de Open-Meteo; la app ya muestra la atribucion |
| Los endpoints `/api/motor/*` y `/api/clima/actualizar` siguen existiendo (legado) y consultan Open-Meteo desde la IP del servidor | Consumen la cuota compartida si alguien los usa | Estan autenticados y con rate limit; retirarlos cuando no queden apps antiguas |
| El cache de reglas es por instancia de la API | Con varias instancias, un cambio de admin tarda hasta 10 min en verse en las otras | Tope de vigencia de 10 min; o un cache distribuido si se escala

## Ver tambien

- [authentication.md](./authentication.md) -- flujo detallado de login (correo y Google), modo invitado y JWT.
- [google-sign-in-setup.md](./google-sign-in-setup.md) -- configuracion de Google Sign-In.
- [error-handling.md](./error-handling.md) -- catalogo de codigos de error.
- [api-reference.md](./api-reference.md) -- referencia completa de endpoints.