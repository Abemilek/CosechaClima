# Mobile Integration Guide

Guia tecnica para la integracion entre la app movil Flutter y el backend ASP.NET Core 10 de CosechaClima.

## Configuracion de entorno

La app usa `--dart-define` para inyectar la URL de la API en tiempo de build:

```bash
# Desarrollo (emulador Android)
flutter run --dart-define=API_URL=http://10.0.2.2:8080

# Desarrollo (dispositivo fisico)
flutter run --dart-define=API_URL=http://192.168.1.100:8080

# Produccion
flutter run --release --dart-define=API_URL=https://api.cosechaclima.example.com
```

La configuracion se lee desde `lib/core/config/environment.dart` usando `String.fromEnvironment`.

> [!WARNING]
> Nunca hardcodear URLs de API en el codigo fuente.

## Flujo de autenticacion

```
1. POST /api/auth/register   -> Crea la cuenta
2. POST /api/auth/login      -> Devuelve { token, nombre }
3. Almacenar token            -> flutter_secure_storage (EncryptedSharedPreferences / Keychain)
4. Cada request posterior     -> Header Authorization: Bearer <token>
5. Si respuesta 401           -> Cerrar sesion automaticamente
```

> [!IMPORTANT]
> Nunca almacenar el token en `SharedPreferences` ni en variables de texto plano. Usar exclusivamente `flutter_secure_storage`.

## Flujo tipico del usuario

### 1. Login

```
POST /api/auth/login
Body: { "telefono": "88887777", "pin": "1234" }
Response: { "token": "eyJ...", "nombre": "Juan Perez" }
```

### 2. Cargar catalogos

```
GET /api/catalogos/cultivos
GET /api/catalogos/tipos-suelo
GET /api/catalogos/etapas-fenologicas
GET /api/catalogos/eventos-climaticos
```

Todos requieren header `Authorization: Bearer <token>`.

### 3. Crear parcela

```
POST /api/parcelas
Body: { "cultivoId": 1, "tipoSueloId": 2, "fechaSiembra": "2026-06-01", "areaMzs": 2.5, "latitud": 11.83, "longitud": -86.18 }
```

### 4. Configurar umbrales (si es la primera vez)

```
POST /api/umbrales
Body: { "lluviaIntensaMm": 100, "vientoFuerteKmh": 40, "caniculaDias": 7, "horarioSms": "06:00" }
```

Si `GET /api/umbrales/mios` devuelve `404`, significa que el usuario no ha configurado umbrales todavia. Flutter debe interpretar esto como "mostrar pantalla de configuracion", no como un error.

### 5. Ver detalle de parcela (pantalla principal)

Este es el flujo que se ejecuta al entrar a la pantalla de detalle de una parcela:

**Paso A -- Actualizar datos climaticos:**

```
POST /api/clima/actualizar/{parcelaId}
Response: DatosClimaticos (temperaturaMax, temperaturaMin, precipitacion, vientoVelocidad, humedadRelativa)
```

**Paso B -- Obtener semaforo de riesgo:**

```
POST /api/motor/semaforo
Body: { "parcelaId": 5 }
Response: { "nivelRiesgo": "Alto", "descripcionAlerta": "...", "acciones": ["Accion 1", "Accion 2", "Accion 3"], "fecha": "2026-09-16" }
```

**Paso C -- Mostrar resultado:**

Tarjeta de riesgo con color segun nivel:

| Nivel | Color | Variante |
|---|---|---|
| Alto | Rojo (`AppColors.red`) | `AppPillVariant.red` |
| Medio | Ambar (`AppColors.amber`) | `AppPillVariant.warn` |
| Bajo | Verde (`AppColors.green`) | - |
| Sin riesgo | Gris (`AppColors.muted`) | - |

> [!IMPORTANT]
> Los cambios de estado de riesgo se comunican exclusivamente mediante color solido y texto en negrita. Cero animaciones, cero transiciones, cero opacidades.

### 6. Registrar en bitacora

```
POST /api/logs
Body: { "parcelaId": 5, "fecha": "2026-09-16", "eventoClimaticoId": 1, "nivelRiesgo": "Alto", "accion1Texto": "...", "accion2Texto": "...", "accion3Texto": "..." }
```

## Manejo de errores HTTP

El `ApiClient` traduce respuestas HTTP a excepciones tipadas:

| Excepcion | Cuando se lanza | Accion recomendada |
|---|---|---|
| `ApiException` | Errores 4xx del servidor | Mostrar `e.message` al usuario |
| `NetworkException` | Sin conexion a internet | Mostrar mensaje de conectividad |
| `TimeoutApiException` | Timeout de la peticion | Sugerir reintentar |

Para errores `404` del motor de decisiones, leer siempre el campo `title` del `ProblemDetails` ya que puede indicar un paso faltante del flujo (no umbrales, no datos climaticos) en lugar de un recurso inexistente.

## Rendimiento

### Parseo JSON en segundo plano

Para colecciones grandes (bitacora, catalogos), el parseo se delega a isolates usando `compute`:

```dart
List<BitacoraEntry> _parseBitacoras(List<dynamic> json) {
  return json
      .map((e) => BitacoraEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<BitacoraEntry>> obtenerMias() async {
  final json = await _client.get('/logs/mias') as List<dynamic>;
  return compute(_parseBitacoras, json);
}
```

### Consumo granular de estado

- Usar `Selector<ViewModel, T>` para observar campos especificos.
- Usar `Consumer<ViewModel>` limitado al subarbol mas pequeno.
- Usar `context.read<ViewModel>()` para lecturas unicas en event handlers.
- Evitar `context.watch<ViewModel>()` a nivel raiz del metodo `build`.

## Politica de Cero Animaciones

**Prohibido:** `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, `animateToPage`, cualquier transicion visual.

**Requerido:** `jumpToPage` para PageView, `Container` estatico para cambios de estado, colores solidos para niveles de riesgo.

## Ver tambien

- [api-reference.md](./api-reference.md) -- referencia completa de endpoints.
- [authentication.md](./authentication.md) -- flujo de login detallado.
- [error-handling.md](./error-handling.md) -- catalogo de errores.
