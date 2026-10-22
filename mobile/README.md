# CosechaClima — Mobile App

<!-- README-I18N:START -->

**English** | [Español](./README.es.md)

<!-- README-I18N:END -->

Flutter app for **CosechaClima**, an agroclimatic risk assistant for small producers in Nicaragua. Since v2.0 the app is **100 % local**: it does not need a backend, an account, an API URL, or any environment file to run. Parcels, thresholds, and the field logbook live on the phone.

---

## What works offline

| Feature | Where | Internet needed |
|---|---|---|
| Traffic light and weekly plan | Phone (`MotorLocal`, Dart) | No (uses the last forecast, valid up to 3 days) |
| 540 agronomic rules + catalogs | Embedded asset `assets/reglas/paquete_reglas.json` | No |
| Parcels, thresholds, logbook | Phone (`SharedPreferences`) | No |
| Backup / restore | JSON copied to the clipboard | No |
| Fresh weather forecast | Direct call to Open-Meteo | Yes, only for the first load or a refresh |
| Accounts, server, Admin Console | Removed from the mobile app | Not used |

The forecast is cached for 2 hours and can be shown offline for up to 3 days. The last full evaluation of each parcel is also stored on the phone as a fallback.

> Weather data: [Open-Meteo.com](https://open-meteo.com/), CC BY 4.0. The free plan is for non-commercial use; the attribution is shown inside the app.

## Requirements

- Flutter SDK (stable channel)
- Android Studio or VS Code with the Flutter extension
- Android/iOS device or emulator

No backend, database, `.env`, or `--dart-define` is required.

## Install and run

```bash
cd mobile
flutter pub get
flutter run
```

Release build:

```bash
flutter build apk --release
# or
flutter build appbundle --release
flutter build ios --release
```

## Local data and backup

Everything is stored in the app's private storage:

| Key | Content |
|---|---|
| `onboarding_visto` | Whether the tutorial was already shown |
| `parcelas_invitado` | Local parcels (the historical key is kept to migrate old guest parcels) |
| `umbral_local` | Risk thresholds |
| `bitacora_local_v1` | Field logbook entries |
| `forecast_*` | Cached Open-Meteo forecasts |
| `evaluacion_local_*` | Last full evaluation of each parcel |

Use **Mis parcelas → Copia de seguridad** to:

1. copy a JSON backup to the clipboard (save it in WhatsApp, email, or a file), and
2. restore it later on the same or a new phone.

Restoring **replaces** the current parcels, logbook, and thresholds. The app also migrates, on first launch, the old server parcel cache (`cache_lista_parcelas`) and old guest parcels so existing users do not lose their data.

## Project structure

```text
mobile/
|-- lib/
|   |-- core/
|   |   |-- app/                  # Onboarding state
|   |   |-- backup/               # (feature) JSON backup and restore
|   |   |-- cache/                # Forecast and last evaluation caches
|   |   |-- clima/                # Open-Meteo client
|   |   |-- config/               # Environment constants and municipality centroids
|   |   |-- local/                # One-time migration from the old server cache
|   |   |-- motor/                # 540-rule engine and embedded package loader
|   |   |-- network/              # Network/timeout exceptions
|   |   |-- services/             # Geolocation and local notifications
|   |-- features/
|   |   |-- parcela/              # Local parcel model, store, wizard, detail, edit
|   |   |-- clima/                # Weekly summary and local engine service
|   |   |-- catalogo/             # Local catalogs from the embedded rule package
|   |   |-- umbral/               # Local risk thresholds
|   |   |-- bitacora/             # Local field logbook
|   |   |-- onboarding/           # Splash, tutorial, about, area forecast
|   |-- routing/                  # App gate and no-animation routes
|   |-- shared/                   # Reusable widgets
|-- assets/reglas/paquete_reglas.json
|-- test/
```

## Rules engine

- `lib/core/motor/motor_local.dart` is pure Dart and is covered by `test/core/motor/motor_local_test.dart`.
- The embedded package contains **540 rules**, 6 climate events, 5 crops, 3 soil types and 6 phenological stages.
- The engine evaluates all active events for the day and picks the most severe risk level (Alto / Medio / Bajo / Sin riesgo) with three recommended actions.
- No network call is needed to calculate the traffic light or the weekly plan.

## Verification

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

## Release signing

`flutter build apk --release` signs with the Android SDK debug key by default, which is not valid for publishing. Generate a private keystore once:

```bash
keytool -genkey -v -keystore ~/cosechaclima-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cosechaclima
```

Create `mobile/android/key.properties` (ignored by git):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=cosechaclima
storeFile=/home/YOUR_USER/cosechaclima-release.jks
```

`android/app/build.gradle.kts` picks it up automatically; without it the build falls back to debug keys. Keep the `.jks` and its passwords backed up: losing them prevents publishing updates with the same identity.

Check the signature:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## Troubleshooting

| Symptom | Cause | Solution |
|---|---|---|
| No fresh weather | No internet | The app shows the cached forecast (up to 3 days) or the last full evaluation |
| Weather is stale | Cache expired and no connection | Reconnect and pull to refresh |
| Data disappeared after changing phones | Local storage is per device | Restore the JSON backup from **Copia de seguridad** |
| No notifications | Notification permission denied | Enable it in Android/iOS settings and in **Ajustar mis alertas** |
| Android build fails after updating dependencies | Stale generated plugins | `flutter clean && flutter pub get` |

The old backend and Admin Console remain in the repository as historical/reference code, but the mobile app no longer calls them.
