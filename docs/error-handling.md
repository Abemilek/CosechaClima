# Error Handling

Cómo interpretar y manejar los errores que devuelve la API.

## Formato estándar

Todos los errores siguen el estándar [RFC 7807 (ProblemDetails)](https://www.rfc-editor.org/rfc/rfc7807):

```json
{
  "status": 400,
  "title": "Descripción legible del error",
  "instance": "/api/parcelas"
}
```

Cualquier cliente puede leer siempre el mismo campo (`title`) para mostrarle algo útil al usuario, sin tener que parsear formatos distintos según el endpoint.

## Catálogo de códigos de estado usados en esta API

| Código | Significado | Cuándo aparece |
|---|---|---|
| `200` | Éxito | Operación completada |
| `400` | Solicitud inválida | Falta un campo requerido, un valor no cumple una regla de validación (`[Range]`, `[Required]`, etc.), o se referenció un id de catálogo que no existe |
| `401` | No autenticado | Falta el token, o expiró |
| `403` | No autorizado | Token válido, pero el recurso pedido no pertenece al usuario autenticado |
| `404` | No encontrado | El recurso no existe, o falta completar un paso previo del flujo de negocio (ej. pedir el semáforo sin haber configurado umbrales) |
| `409` | Conflicto | Se intentó crear un recurso que ya existe (ej. registrar un teléfono duplicado) |
| `429` | Demasiadas solicitudes | Rate limiting activo en `/api/auth/register` y `/api/auth/login` (máx. 5/minuto) |
| `503` | Servicio no disponible | Un servicio externo (Open-Meteo) no respondió y no hay dato de respaldo guardado |

## Cómo se generan internamente (para quien mantenga el backend)

Todas las excepciones no controladas pasan por `ManejadorErroresGlobal` (`IExceptionHandler`), que traduce tipos específicos de excepción a códigos HTTP apropiados:

```csharp
var (statusCode, titulo) = exception switch
{
    UnauthorizedAccessException => (401, "No autorizado"),
    InvalidOperationException   => (400, exception.Message),
    SqlException { Number: 547 }         => (400, "uno de los valores referenciados no existe en el catalogo"),
    SqlException { Number: 2601 or 2627 } => (409, "ya existe un registro con esos mismos datos"),
    _ => (500, "ocurrio un error inesperado")
};
```

Cualquier excepción no cubierta explícitamente cae en `500` genérico — el detalle completo queda registrado en el log del servidor, nunca expuesto al cliente.

## Buenas prácticas para quien consuma la API

- Nunca asumas que un `404` es siempre "no existe" — en varios endpoints de negocio (como el semáforo) puede significar "falta un paso previo del flujo". Leé siempre el `title`.
- Un `403` en uso normal de la app **no debería ocurrir nunca** — si tu cliente solo pide sus propios recursos (vía tu propio token), aparecerlo indica un bug, no un caso esperado de negocio.
- Ante un `429`, no reintentes inmediatamente — esperá al menos un minuto; reintentar en loop solo empeora el bloqueo.
