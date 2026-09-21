# Mobile Integration Guide

Guia tecnica para la integracion entre la app movil Flutter y el backend ASP.NET Core 10 de CosechaClima.

## Configuracion de entorno

La app usa `--dart-define` para inyectar variables en tiempo de build. Lo recomendado es un archivo `mobile/.env` (copia de `mobile/.env.example`):

```bash
flutter run --dart-define-from-file=.env
```

| Variable | Obligatoria | Descripcion |
|---|---|---|
| `API_URL` | Si | **Solo la base de la API**, sin ruta: `http://10.0.2.2:8080` (emulador), `http://192.168.1.100:8080` (dispositivo fisico) o `https://api.cosechaclima.example.com` (produccion) |
| `GOOGLE_SERVER_CLIENT_ID` | No | Client ID **Web** de Google Cloud. Si esta vacio, la app oculta el boton "Continuar con Google" |

O sin archivo:

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8080 --dart-define=GOOGLE_SERVER_CLIENT_ID=<client id web>
```

La configuracion se lee desde `lib/core/config/environment.dart` usando `String.fromEnvironment`. Como se resuelve en **compilacion**, cambiar el `.env` exige detener la app y volver a lanzarla (un hot restart no basta).

> [!WARNING]
> Nunca hardcodear URLs de API en el codigo fuente.

> [!IMPORTANT]
> `API_URL` no debe incluir rutas. La app agrega `/api` y el endpoint (`API_URL` + `/api` + `/auth/login`). Un valor como `https://host/swagger/index.html` o `https://host/api` produce un `404` en todas las pantallas.

> [!NOTE]
> Android bloquea `http://` por defecto. El manifest de **debug** lo permite para desarrollo local; los builds de release exigen `https://`.

## Modo invitado y flujo de autenticacion

La app **no obliga a tener cuenta**. El onboarding se muestra una sola vez y despues se entra siempre al inicio: un **inicio publico** para quien no tiene sesion, o el inicio normal (lista de parcelas, o panel de administrador) para quien si.

| Area | Sin cuenta (invitado) | Con cuenta |
|---|---|---|
| Onboarding / tutorial | Si | Si |
| Pronostico de 5 dias de la zona | Si -- `GET /api/clima/pronostico` (Carazo aproximado, o "Usar mi ubicacion") | Si |
| Catalogos de referencia | Publicos en la API | Si |
| Parcelas, umbrales, clima de parcela, semaforo, bitacora | No -- pide iniciar sesion | Si |
| Panel de administracion | No | Solo rol `Admin` |

**La sesion se pide en un solo punto.** Al tocar "Mis parcelas" en el inicio publico, la app abre el login contextual (`mostrarLoginContextual`) con el motivo ("Para guardar tu parcela necesitas una cuenta") y, si el login sale bien, continua a lo que el usuario queria hacer. Cancelar deja al usuario donde estaba.

```
1. Abrir la app            -> onboarding (solo la primera vez) -> inicio publico
2. Tocar algo privado      -> login contextual (Google o correo)
3a. Continuar con Google   -> SDK de Google -> idToken -> POST /api/auth/google
3b. Correo y contrasena    -> POST /api/auth/register  o  POST /api/auth/login
4. Respuesta de las tres   -> { token, nombre, email, fotoUrl, esAdmin }
5. Guardar el token         -> flutter_secure_storage (EncryptedSharedPreferences / Keychain)
6. Cada request posterior   -> Header Authorization: Bearer <token>
7. Si respuesta 401         -> Cerrar sesion y volver al inicio publico (aviso: "Volviste al modo publico")
```

> [!IMPORTANT]
> Nunca almacenar el token en `SharedPreferences` ni en variables de texto plano. Usar exclusivamente `flutter_secure_storage`. En `SharedPreferences` solo van datos **no sensibles** para mostrar la UI: nombre, correo, URL de la foto y el indicador de onboarding visto.

Reglas de la pantalla de correo (`EmailAuthScreen`): pestanas "Soy nuevo" (nombre, correo, contrasena) y "Ya tengo cuenta" (correo, contrasena); correo con formato valido y contrasena de al menos 8 caracteres. Los mismos limites los valida el backend.

Google en Android requiere que el `serverClientId` sea el Client ID **Web** y que el paquete y el SHA-1 esten registrados en Google Cloud. Ver [google-sign-in-setup.md](./google-sign-in-setup.md).

## Flujo tipico del usuario

### 0. Inicio publico (sin cuenta)

```
GET /api/clima/pronostico?latitud=11.85&longitud=-86.199
Response: [ { "fecha": "2026-09-20T00:00:00", "temperaturaMax": 31.2, "temperaturaMin": 21.4, "precipitacion": 6.1, "vientoVelocidad": 18.0 }, ... ]
```

No requiere token. Si responde `503`, la app muestra un error con boton "Reintentar" (Open-Meteo no disponible). Por defecto se consulta un punto de Carazo (Jinotepe); al tocar "Usar mi ubicacion" se pide el GPS y, si el usuario lo niega o falla, se conserva el punto por defecto.

### 1. Login

```
POST /api/auth/login
Body: { "email": "juan@example.com", "password": "una-clave-larga" }
Response: { "token": "eyJ...", "nombre": "Juan Perez", "email": "juan@example.com", "fotoUrl": null, "esAdmin": false }
```

Registro (`POST /api/auth/register`, body `{ nombre, email, password }`) y Google (`POST /api/auth/google`, body `{ idToken }`) devuelven la misma respuesta.

### 2. Cargar catalogos

```
GET /api/catalogos/cultivos
GET /api/catalogos/tipos-suelo
GET /api/catalogos/etapas-fenologicas
GET /api/catalogos/eventos-climaticos
```

Son publicos: no requieren token (la app igual lo envia si hay sesion).

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

Para los errores de autenticacion y del pronostico publico el mensaje viene en `mensaje` en vez de `title`; el `ApiClient` lee ambos y los expone en `e.message`.

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
- [google-sign-in-setup.md](./google-sign-in-setup.md) -- configuracion de Google Sign-In.
- [error-handling.md](./error-handling.md) -- catalogo de errores.