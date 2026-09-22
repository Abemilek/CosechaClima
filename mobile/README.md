# CosechaClima -- Mobile App

<!-- README-I18N:START -->

**English** | [Español](./README.es.md)

<!-- README-I18N:END -->

Flutter mobile client for the CosechaClima agroclimatic alert system. It consumes the ASP.NET Core 10 backend REST API and presents weather risk alerts with recommended actions for agricultural producers.

---

## Table of Contents

- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Environment configuration](#environment-configuration)
- [Project structure](#project-structure)
- [Rendering philosophy: Zero Animations](#rendering-philosophy-zero-animations)
- [Performance optimizations](#performance-optimizations)
- [State management](#state-management)
- [Guest mode and authentication](#guest-mode-and-authentication)
- [Security](#security)
- [API integration](#api-integration)
- [Release build](#release-build)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Flutter SDK (stable channel)
- Dart SDK (bundled with Flutter)
- Android Studio or VS Code with the Flutter extension
- Physical device or emulator (Android/iOS)
- Backend API running (see [../backend/README.md](../backend/README.md) or root `compose.yaml`)

## Installation

```bash
cd mobile
flutter pub get
```

## Environment configuration

The app injects environment variables at **build time** via `--dart-define-from-file` or `--dart-define`. Configuration is read from `lib/core/config/environment.dart` using `String.fromEnvironment`.

### Step 1 -- Create the `.env` file

```bash
cd mobile
cp .env.example .env
```

Edit `.env` with the backend URL for your environment:

```bash
# Android emulator
API_URL=http://10.0.2.2:8080

# Physical device (use the machine's local IP)
API_URL=http://192.168.1.100:8080

# Production
API_URL=https://api.cosechaclima.example.com

# Google Sign-In (optional): WEB-type Client ID, not the Android one
GOOGLE_SERVER_CLIENT_ID=
```

| Variable | Required | Description |
|---|---|---|
| `API_URL` | Yes | API base. **Domain and port only, no paths** |
| `GOOGLE_SERVER_CLIENT_ID` | No | Google Cloud Web Client ID. If empty, the app hides the "Continue with Google" button and only offers email and password. See [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |

> [!NOTE]
> `10.0.2.2` is the Android emulator's alias for the host machine's localhost. For physical devices, use the real local IP.

> [!IMPORTANT]
> `API_URL` **must not include a path**. The app builds each request as `API_URL` + `/api` + the endpoint. A value like `https://host/swagger/index.html` or `https://host/api` makes every screen fail with `Error inesperado (404)`.

> [!NOTE]
> Android 9+ blocks `http://` by default. The **debug** manifest allows it for local development (e.g. `http://10.0.2.2:8080`); release builds require `https://`.

### Step 2 -- Run with the `.env` file

```bash
flutter run --dart-define-from-file=.env
```

**Alternative without a file** (passing the variable directly):

```bash
flutter run --dart-define=API_URL=http://10.0.2.2:8080
```

### Behavior when `API_URL` is missing

The app **won't start** if `API_URL` is not defined. On launch, `Environment.validate()` throws an explicit exception:

```
Exception: API_URL is required.
Run with: flutter run --dart-define-from-file=.env
See mobile/.env.example for setup instructions.
```

Because values are resolved at **compile time**, every `.env` change requires stopping the app and relaunching it; a hot reload or hot restart won't apply it.

> [!WARNING]
> There is no fallback to any default URL. Always create the `.env` file before running. The `.env` file must not be committed to version control.

## Project structure

```
mobile/
|-- lib/
|   |-- core/
|   |   |-- config/
|   |   |   |-- environment.dart          # Variables de entorno via --dart-define (API_URL, GOOGLE_SERVER_CLIENT_ID)
|   |   |-- network/
|   |   |   |-- api_client.dart           # Cliente HTTP con interceptor JWT
|   |   |   |-- api_exception.dart        # Excepciones tipadas de API
|   |   |-- theme/
|   |       |-- app_theme.dart            # Colores, radios, tipografia
|   |-- features/
|   |   |-- auth/                         # Google Sign-In, correo y contrasena, login contextual
|   |   |-- parcela/                      # Gestion de parcelas, pantalla de detalle
|   |   |-- clima/                        # Datos climaticos, pronostico publico, motor de decisiones
|   |   |-- umbral/                       # Umbrales de riesgo del usuario
|   |   |-- bitacora/                     # Bitacora de campo
|   |   |-- catalogo/                     # Datos de catalogo (cultivos, suelos, etc.)
|   |   |-- onboarding/                   # Tutorial (una sola vez) e inicio publico
|   |-- shared/
|       |-- widgets/                      # Componentes reutilizables (AppAvatar, AppPill)
|-- pubspec.yaml
```

## Rendering philosophy: Zero Animations

This app follows a strict **Zero Animations** policy. The goal is pure performance and straightforward UX for farming users in resource-constrained environments.

**Forbidden:**

- `AnimatedContainer`, `AnimatedOpacity`, `AnimatedSwitcher`, or any `Animated*` widget
- `animateToPage` or any animated page transition
- Dynamic floating alerts or toast animations
- Opacity transitions or expand animations
- `CircularProgressIndicator` with an animated appearance

**Required:**

- `jumpToPage` for all PageView navigation (instant, no transition)
- Static color and text changes for state updates
- Risk levels (High, Medium, Low) are communicated through solid color blocks (red, amber, green) and bold text, not through visual effects
- Direct widget replacement with no transition effects

> [!IMPORTANT]
> Any PR introducing animated widgets will be rejected. Risk levels are communicated exclusively through static color coding and bold text.

## Performance optimizations

### Background JSON parsing with isolates

For services returning large JSON payloads (logbook history, catalog lists), parsing is delegated to background isolates using Dart's `compute` function to avoid blocking the UI thread.

Example from `BitacoraService`:

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
> The parsing function must be a top-level function, not a method or closure, so it can be sent to the isolate.

### Granular state consumption

Avoid root-level `context.watch<ViewModel>()` calls that trigger full widget-tree rebuilds. Use instead:

- `Selector<ViewModel, T>` to observe specific fields
- `Consumer<ViewModel>` scoped to the smallest possible subtree
- `context.read<ViewModel>()` for one-off reads (event handlers, initState)

## State management

The app uses `Provider` for state management.

**Principles:**

- ViewModels extend `ChangeNotifier`.
- Each feature has its own ViewModel (`AuthViewModel`, `ParcelaViewModel`, etc.).
- State is consumed granularly using `Selector` and `Consumer` to minimize rebuilds.
- No global state observation in root `build` methods.

## Guest mode and authentication

The app **doesn't require an account**. The onboarding shows only once (first launch) and afterwards you always land on the home screen:

| State | Home screen |
|---|---|
| No session (guest) | `PublicHomeScreen`: 5-day area forecast |
| With session | `ParcelaListScreen` (producer) or `AdminHomeScreen` (Admin role) |

| Area | Guest | With account |
|---|---|---|
| Onboarding | Yes | Yes |
| Area forecast (approximate Carazo, or "Use my location") | Yes | Yes |
| Plots, thresholds, plot weather, traffic light, logbook | No, asks to sign in | Yes |
| Admin panel | No | Admin role only |

**Sign-in is requested at a single point.** Tapping "Mis parcelas" on the public home opens a contextual login (`mostrarLoginContextual`) explaining why. On success, the app continues to what the user wanted to do; on cancel, it stays where it was.

**Sign-in methods:**

- **Continue with Google** (`AuthService.loginConGoogle`): the SDK returns an `idToken` and the app sends it to `POST /api/auth/google`. Requires `GOOGLE_SERVER_CLIENT_ID` and the package plus SHA-1 fingerprint registered in Google Cloud.
- **Email and password** (`EmailAuthScreen`): "Soy nuevo" tabs (`POST /api/auth/register`) and "Ya tengo cuenta" (`POST /api/auth/login`). Valid email format and password of at least 8 characters.

All three responses return `{ token, nombre, email, fotoUrl, esAdmin }`. If the backend answers `401` on a protected endpoint (expired token), `AuthViewModel` signs out and the app returns to the public home with the notice "Tu sesión expiró. Volviste al modo público."

`AuthViewModel` exposes `estado` (`desconocido`, `autenticado`, `invitado`), `estaAutenticado`, `esAdmin` and `onboardingVisto`. See [../docs/mobile-integration-guide.md](../docs/mobile-integration-guide.md) for the flow detail.

## Security

### JWT token storage

JWT tokens are stored using `flutter_secure_storage`, which uses:

- **Android:** EncryptedSharedPreferences (AES-256)
- **iOS:** Keychain Services

> [!WARNING]
> Never store tokens in `SharedPreferences` or plain-text variables. Always use `flutter_secure_storage`.

`SharedPreferences` only keeps **non-sensitive** data for rendering the UI: name, email, photo URL and the onboarding-seen flag. On sign-out the token and that data are wiped, and the Google session is closed.

The Google Client ID shipped in the app is not a secret; the *client secret* is never used nor bundled into the app.

### HTTP client and token handling

The `ApiClient` class handles:

- Automatic `Authorization: Bearer <token>` header injection on all authenticated requests.
- Translation of HTTP errors into typed exceptions (`ApiException`, `NetworkException`, `TimeoutApiException`).
- Automatic sign-out on 401 responses (expired token): the app returns to public mode.
- Reading the error message from `title` or `mensaje` depending on the endpoint.

## API integration

The app communicates with the backend via REST endpoints. Without an account it only uses `GET /api/clima/pronostico` (public). With an account, the typical flow to see a plot's risk status:

1. `POST /api/clima/actualizar/{parcelaId}` -- fetch latest weather data
2. `POST /api/motor/semaforo` -- calculate risk traffic light
3. Show risk card with color-coded severity and 3 actions
4. `POST /api/logs` -- save to the field logbook when the user confirms

See the [API Reference](../docs/api-reference.md) for full endpoint documentation.

## Release build

> [!WARNING]
> The `API_URL` variable is **mandatory** in production builds. Without it, the app throws an exception on launch.

**Using a `.env` file** (recommended):

```bash
flutter build apk --release --dart-define-from-file=.env
flutter build appbundle --release --dart-define-from-file=.env
flutter build ios --release --dart-define-from-file=.env
```

**Using a direct variable:**

```bash
flutter build apk --release --dart-define=API_URL=https://api.cosechaclima.example.com
```

In release, `API_URL` must be `https://`: `http://` traffic is only allowed in the debug manifest.

### APK signing (mandatory before publishing v1.0)

By default, `flutter build apk --release` signs with the Android SDK's **debug key**.
That key is public and shared by every SDK installation, so anyone can re-sign the APK and
impersonate the app. For a published release, generate your own keystore once:

```bash
keytool -genkey -v -keystore ~/cosechaclima-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cosechaclima
```

Then create `mobile/android/key.properties` (already in `.gitignore`, not versioned):

```properties
storePassword=LA_PASSWORD_DEL_KEYSTORE
keyPassword=LA_PASSWORD_DE_LA_CLAVE
keyAlias=cosechaclima
storeFile=/home/TU_USUARIO/cosechaclima-release.jks
```

`android/app/build.gradle.kts` detects that file automatically: if it
exists it signs with your keystore, otherwise it falls back to debug keys so
`flutter run --release` keeps working in development.

> [!CAUTION]
> Keep the `.jks` and its passwords somewhere safe and backed up.
> If you lose them, you won't be able to publish app updates
> signed with the same identity -- Android rejects them as if they were
> from another developer.

Check which key the APK was signed with:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

If the owner says `CN=Android Debug`, the keystore wasn't picked up.

> [!IMPORTANT]
> Google Sign-In recognizes the app by its package and the **SHA-1 of the signing keystore**. Each keystore (debug, release and, if published on Google Play with Play App Signing, Play's) needs its own Android-type Client ID in Google Cloud; otherwise Google login fails on that build with `ApiException: 10`. See [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md).

### Application ID

The `applicationId` is `ni.edu.unan.cosechaclima`. It used to be
`com.example.mobile`: the `com.example` prefix is reserved for
samples and Google Play rejects any APK using it. This value is
**permanent** once the app is published -- changing it later forces you to
publish a brand-new app from scratch.

The Google Cloud Android Client ID must use this same package. If you change it, that Client ID must be created or updated.

## Troubleshooting

| Symptom | Likely cause | Solution |
|---|---|---|
| `Error inesperado (404)` on forecast, login and registration | `API_URL` has an extra path (`/swagger/...`, `/api`) or points to another service | Keep only domain and port, and relaunch the app |
| The app won't start and throws `API_URL is required` | Empty `mobile/.env` or `--dart-define-from-file=.env` wasn't passed | Fill in `API_URL` and run `flutter run --dart-define-from-file=.env` |
| I changed `.env` but the app looks the same | Values are resolved at compile time | Stop the app and relaunch it |
| "Continuar con Google" doesn't show up | Empty `GOOGLE_SERVER_CLIENT_ID` | Fill it with the Web Client ID and relaunch |
| Google fails with `ApiException: 10` | Package or SHA-1 doesn't match the Android Client ID | See [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |
| `Cleartext HTTP traffic not permitted` | Release build against an `http://` URL | Use `https://` in release; in debug the manifest already allows it |
| Creating an account with a **new** email says "Ya existe un registro con esos mismos datos" | The database was created with a plain `UNIQUE` constraint on `GoogleUid` (only allows one `NULL`) | Recreate the database with the current `BD-CosechaClima.sql` (`docker compose down -v`). If the message is "ya existe una cuenta con este correo", just sign in |