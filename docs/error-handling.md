# Error Handling

Como interpretar y manejar los errores que devuelve la API.

## Formato estandar

Todos los errores siguen el estandar [RFC 7807 (ProblemDetails)](https://www.rfc-editor.org/rfc/rfc7807):

```json
{
  "status": 400,
  "title": "Descripcion legible del error",
  "instance": "/api/parcelas"
}
```

Cualquier cliente puede leer siempre el mismo campo (`title`) para mostrarle algo util al usuario, sin tener que parsear formatos distintos segun el endpoint.

## Catalogo de codigos de estado

| Codigo | Significado | Cuando aparece |
|---|---|---|
| `200` | Exito | Operacion completada |
| `400` | Solicitud invalida | Falta un campo requerido, valor no cumple validacion, o referencia a id de catalogo inexistente |
| `401` | No autenticado | Falta el token, o expiro |
| `403` | No autorizado | Token valido, pero el recurso no pertenece al usuario autenticado |
| `404` | No encontrado | El recurso no existe, o falta completar un paso previo del flujo de negocio |
| `409` | Conflicto | Se intento crear un recurso que ya existe (ej. telefono duplicado) |
| `429` | Demasiadas solicitudes | Rate limiting activo en `/api/auth/*` y `/api/motor/semaforo` |
| `503` | Servicio no disponible | Un servicio externo (Open-Meteo) no respondio y no hay dato de respaldo |

## Como se generan internamente

Todas las excepciones no controladas pasan por `ManejadorErroresGlobal` (`IExceptionHandler`), que traduce tipos especificos de excepcion a codigos HTTP apropiados:

| Tipo de excepcion | Codigo HTTP | Titulo |
|---|---|---|
| `RecursoNoEncontradoException` | `404` | Mensaje de la excepcion |
| `FlujoIncompletoException` | `404` | Mensaje de la excepcion |
| `UnauthorizedAccessException` | `401` | "No autorizado" |
| `SqlException { Number: 547 }` | `400` | "Uno de los valores referenciados no existe en el catalogo" |
| `SqlException { Number: 2601 or 2627 }` | `409` | "Ya existe un registro con esos mismos datos" |
| Cualquier otra excepcion | `500` | "Ocurrio un error inesperado" |

> [!NOTE]
> El detalle completo de excepciones 500 queda registrado en el log del servidor y nunca se expone al cliente.

## Buenas practicas para consumidores de la API

- Nunca asumir que un `404` es siempre "no existe" -- en endpoints de negocio (como el semaforo) puede significar "falta un paso previo del flujo". Leer siempre el `title`.
- Un `403` en uso normal de la app no deberia ocurrir nunca -- indica un bug si aparece.
- Ante un `429`, no reintentar inmediatamente -- esperar al menos un minuto.
- Siempre leer el campo `title` del `ProblemDetails` para mostrar mensajes utiles al usuario final.
