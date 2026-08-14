# Security

Resumen del modelo de seguridad de la API — qué se implementó y por qué. El detalle exhaustivo de la revisión que originó estas decisiones vive en el historial de PRs del repositorio; esto es la versión de referencia rápida.

## Autenticación
JWT Bearer, expiración de 24 horas. PIN de 4 dígitos, nunca almacenado en texto plano — hash SHA-256 con salt individual por usuario, comparado con `CryptographicOperations.FixedTimeEquals` (comparación de tiempo constante, mitiga timing attacks).

## Autorización y control de acceso
Todo endpoint de negocio requiere `[Authorize]`. El id de usuario para decidir "de quién son estos datos" se deriva siempre del claim del token (`ClaimTypes.NameIdentifier`), nunca de un parámetro de URL o del body — esto cierra el patrón de vulnerabilidad conocido como **IDOR** (Insecure Direct Object Reference / Broken Object Level Authorization, [OWASP API Security Top 10](https://owasp.org/API-Security/editions/2023/en/0x00-header/), categoría API1:2023).

Endpoints administrativos (siembra y actualización del árbol de reglas) requieren además el rol `Admin`, asignado manualmente vía base de datos — no existe autopromoción por API.

## Validación de entrada y mass assignment
Los endpoints de escritura reciben DTOs de request dedicados (`ParcelaRequestDto`, `BitacoraRequestDto`, `UmbralRequestDto`), nunca las entidades de dominio completas — así el cliente solo puede escribir los campos que el DTO expone explícitamente. Cierra el patrón **Broken Object Property Level Authorization** (OWASP API3:2023). Validación declarativa con `DataAnnotations` (`[Required]`, `[Range]`, `[RegularExpression]`).

## Rate limiting
Ventana deslizante (5 peticiones/minuto) en `/api/auth/register` y `/api/auth/login`, mitigando fuerza bruta contra el PIN de 4 dígitos.

## Manejo de errores
`IExceptionHandler` centralizado; ninguna excepción expone detalles internos (stack traces, mensajes de SQL Server) al cliente. Ver [`error-handling.md`](./error-handling.md).

## Secretos
Gestionados por variables de entorno (`.env`, excluido de git). `appsettings.json` versionado sin valores reales. Ninguna clave hardcodeada en el código fuente.

## Limitaciones conocidas (documentadas, no ocultas)
- El rate limiting es global por servidor, no por IP.
- Sin versionado de API (`/api/v1/...`).
- Cobertura de pruebas automatizadas mínima.
- El contenido agronómico del árbol de decisión es preliminar, generado de forma sistemática, pendiente de validación técnica formal.

## Referencia usada
[OWASP API Security Top 10 (2023)](https://owasp.org/API-Security/editions/2023/en/0x00-header/) — marco de referencia para identificar y priorizar los hallazgos de seguridad de este proyecto.
