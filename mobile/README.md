# CosechaClima -- App Movil

Cliente movil Flutter para el sistema de alerta agroclimatica CosechaClima. Consume la API REST del backend ASP.NET Core 10 y presenta alertas de riesgo climatico con acciones recomendadas para productores agricolas.

---

## Tabla de contenidos

- [Requisitos previos](#requisitos-previos)
- [Instalacion](#instalacion)
- [Configuracion de entorno](#configuracion-de-entorno)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Filosofia de renderizado: Cero Animaciones](#filosofia-de-renderizado-cero-animaciones)
- [Optimizaciones de rendimiento](#optimizaciones-de-rendimiento)
- [Gestion de estado](#gestion-de-estado)
- [Seguridad](#seguridad)
- [Integracion con la API](#integracion-con-la-api)
- [Compilacion para release](#compilacion-para-release)

---

## Requisitos previos

- Flutter SDK (canal estable)
- Dart SDK (incluido con Flutter)
- Android Studio o VS Code con extension Flutter
- Dispositivo fisico o emulador (Android/iOS)
- Backend API ejecutandose (ver [../backend/README.md](../backend/README.md) o `compose.yaml` en la raiz)

## Instalacion

```bash
cd mobile
flutter pub get
```

## Configuracion de entorno

La app inyecta variables de entorno en **tiempo de compilacion** mediante `--dart-define-from-file` o `--dart-define`. La configuracion se lee desde `lib/core/config/environment.dart` usando `String.fromEnvironment`.

### Paso 1 -- Crear el archivo `.env`

```bash
cd mobile
cp .env.example .env
```

Editar `.env` con la URL del backend segun el entorno:

```bash
# Emulador Android
API_URL=http://10.0.2.2:8080

# Dispositivo fisico (usar la IP local de la maquina)
API_URL=http://192.168.1.100:8080

# Produccion
API_URL=https://api.cosechaclima.example.com
```

> [!NOTE]
> `10.0.2.2` es el alias del emulador Android para el localhost de la maquina host. Para dispositivos fisicos, usar la IP local real.

### Paso 2 -- Ejecutar con el archivo `.env`

```bash
flutter run --dart-define-from-file=.env
```

**Alternativa sin archivo** (pasando la variable directamente):

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

### Comportamiento si falta `API_URL`

La app **no arranca** si `API_URL` no esta definida. Al iniciar, `Environment.validate()` lanza una excepcion explicita:

```
Exception: API_URL is required.
Run with: flutter run --dart-define-from-file=.env
See mobile/.env.example for setup instructions.
```

> [!WARNING]
> No existe fallback a ninguna URL por defecto. Siempre crear el archivo `.env` antes de ejecutar. El archivo `.env` no debe subirse a control de versiones.

## Estructura del proyecto

```
mobile/
|-- lib/
|   |-- core/
|   |   |-- config/
|   |   |   |-- environment.dart          # Variables de entorno via --dart-define
|   |   |-- network/
|   |   |   |-- api_client.dart           # Cliente HTTP con interceptor JWT
|   |   |   |-- api_exception.dart        # Excepciones tipadas de API
|   |   |-- theme/
|   |       |-- app_theme.dart            # Colores, radios, tipografia
|   |-- features/
|   |   |-- auth/                         # Login, registro
|   |   |-- parcela/                      # Gestion de parcelas, pantalla de detalle
|   |   |-- clima/                        # Datos climaticos, motor de decisiones
|   |   |-- umbral/                       # Umbrales de riesgo del usuario
|   |   |-- bitacora/                     # Bitacora de campo
|   |   |-- catalogo/                     # Datos de catalogo (cultivos, suelos, etc.)
|   |   |-- onboarding/                   # Pantallas de tutorial
|   |-- shared/
|       |-- widgets/                      # Componentes reutilizables (AppAvatar, AppPill)
|-- pubspec.yaml
```

## Filosofia de renderizado: Cero Animaciones

Esta aplicacion sigue una politica estricta de **Cero Animaciones**. El objetivo es rendimiento puro y UX directa para usuarios agricolas en entornos de recursos limitados.

**Prohibido:**

- `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, o cualquier widget `Animated*`
- `animateToPage` o cualquier transicion animada de pagina
- Alertas flotantes dinamicas o animaciones de toast
- Transiciones de opacidad o animaciones de expansion
- `CircularProgressIndicator` con apariencia animada

**Requerido:**

- `jumpToPage` para toda navegacion de PageView (instantaneo, sin transicion)
- Cambios estaticos de color y texto para actualizaciones de estado
- Los niveles de riesgo (Alto, Medio, Bajo) se comunican a traves de bloques de color solido (rojo, ambar, verde) y texto en negrita, no a traves de efectos visuales
- Reemplazo directo de widgets sin efectos de transicion

> [!IMPORTANT]
> Cualquier PR que introduzca widgets animados sera rechazado. Los niveles de riesgo se comunican exclusivamente mediante colorimetria estatica y texto contundente.

## Optimizaciones de rendimiento

### Parseo JSON en segundo plano con Isolates

Para servicios que retornan payloads JSON grandes (historial de bitacora, listas de catalogo), el parseo se delega a isolates en segundo plano usando la funcion `compute` de Dart para prevenir bloqueos del hilo de UI.

Ejemplo de `BitacoraService`:

```dart
import 'package:flutter/foundation.dart';

// Funcion de alto nivel requerida por compute para el Isolate
List<BitacoraEntry> _parseBitacoras(List<dynamic> json) {
  return json
      .map((e) => BitacoraEntry.fromJson(e as Map<String, dynamic>))
      .toList();
}

Future<List<BitacoraEntry>> obtenerMias() async {
  final json = await _client.get('/logs/mias') as List<dynamic>;
  return compute(_parseBitacoras, json); // Ejecuta en isolate secundario
}
```

> [!NOTE]
> La funcion de parseo debe ser una funcion de alto nivel (top-level), no un metodo ni un closure, para que `compute` pueda serializarla al isolate.

### Consumo granular de estado

Evitar llamadas `context.watch<ViewModel>()` a nivel raiz que disparan rebuilds completos del arbol de widgets. En su lugar usar:

- `Selector<ViewModel, T>` para observar campos especificos
- `Consumer<ViewModel>` limitado al subarbol mas pequeno posible
- `context.read<ViewModel>()` para lecturas unicas (event handlers, initState)

## Gestion de estado

La app usa `Provider` para gestion de estado.

**Principios:**

- Los ViewModels extienden `ChangeNotifier`.
- Cada feature tiene su propio ViewModel (`AuthViewModel`, `ParcelaViewModel`, etc.).
- El estado se consume de forma granular usando `Selector` y `Consumer` para minimizar rebuilds.
- No se permiten observaciones globales de estado en los metodos `build` raiz.

## Seguridad

### Almacenamiento de token JWT

Los tokens JWT se almacenan usando `flutter_secure_storage`, que utiliza:

- **Android:** EncryptedSharedPreferences (AES-256)
- **iOS:** Keychain Services

> [!WARNING]
> Nunca almacenar tokens en `SharedPreferences` ni en variables de texto plano. Siempre usar `flutter_secure_storage`.

### Cliente HTTP y manejo de tokens

La clase `ApiClient` gestiona:

- Inyeccion automatica del header `Authorization: Bearer <token>` en todas las peticiones autenticadas.
- Traduccion de errores HTTP a excepciones tipadas (`ApiException`, `NetworkException`, `TimeoutApiException`).
- Terminacion automatica de sesion ante respuestas 401 (token expirado).

## Integracion con la API

La app se comunica con el backend via endpoints REST. El flujo tipico para ver el estado de riesgo de una parcela:

1. `POST /api/clima/actualizar/{parcelaId}` -- obtener datos climaticos mas recientes
2. `POST /api/motor/semaforo` -- calcular semaforo de riesgo
3. Mostrar tarjeta de riesgo con severidad codificada por color y 3 acciones
4. `POST /api/logs` -- guardar en bitacora de campo cuando el usuario confirma

Ver [Referencia de API](../docs/api-reference.md) para documentacion completa de endpoints.

## Compilacion para release

> [!WARNING]
> La variable `API_URL` es **obligatoria** en builds de produccion. Sin ella, la app lanza una excepcion al iniciar.

**Usando archivo `.env`** (recomendado):

```bash
flutter build apk --release --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
flutter build ios --release --dart-define-from-file=.env
```

**Usando variable directa:**

```bash
flutter build apk --release --dart-define=API_URL=https://api.cosechaclima.example.com
```