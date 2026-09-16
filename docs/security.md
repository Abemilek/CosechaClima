# Security

Decisiones de seguridad, hallazgos resueltos y politicas de proteccion de la API CosechaClima. Alineado con [OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x00-header/).

## Autenticacion

- **JWT Bearer** con firmado HMAC-SHA256.
- Clave secreta minimo 32 caracteres (256 bits), validada al arranque.
- Claim `Jti` (JWT ID) generado como GUID en cada login para unicidad de token y prevencion de replay attacks.
- Expiracion configurable (default: 24 horas).
- PIN de usuario almacenado como hash PBKDF2 + salt aleatorio individual por usuario. El PIN en texto plano nunca se persiste.
- Comparacion de hash usando `CryptographicOperations.FixedTimeEquals` para mitigar timing attacks.

## Autorizacion

- **Ownership-based access control:** todos los recursos (parcelas, umbrales, bitacora, clima) verifican que el `UsuarioId` del recurso coincida con el claim `NameIdentifier` del token JWT. Nunca se acepta un `usuarioId` como parametro de URL o body.
- **Rol Admin:** separado para operaciones administrativas (sembrado y aplicacion de reglas). No existe endpoint HTTP para auto-promoverse -- otorgado exclusivamente via seed de base de datos o SQL directo.
- `[Authorize]` aplicado a nivel de clase en todos los controladores de negocio.
- `[Authorize(Roles = "Admin")]` en los 3 endpoints de `ReglaDecisionController`.

## Rate Limiting

| Politica | Tipo | Limite | Endpoints protegidos |
|---|---|---|---|
| `auth` | Ventana deslizante | 5 peticiones/minuto por IP | `POST /api/auth/register`, `POST /api/auth/login` |
| `motor` | Aplicada al controlador | Previene abuso computacional | `POST /api/motor/semaforo` |

Respuesta al exceder el limite: `429 Too Many Requests`.

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

## Seguridad en el cliente movil (Flutter)

- Token JWT almacenado en `flutter_secure_storage` (EncryptedSharedPreferences en Android, Keychain en iOS).
- Nunca almacenado en `SharedPreferences` ni en variables de texto plano.
- Cierre de sesion automatico ante respuestas `401` (token expirado).
- URLs de API inyectadas via `--dart-define`, nunca hardcodeadas.

## Ver tambien

- [authentication.md](./authentication.md) -- flujo detallado de login y JWT.
- [error-handling.md](./error-handling.md) -- catalogo de codigos de error.
- [api-reference.md](./api-reference.md) -- referencia completa de endpoints.
