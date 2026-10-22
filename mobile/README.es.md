# CosechaClima — App móvil

<!-- README-I18N:START -->

[English](./README.md) | **Español**

<!-- README-I18N:END -->

Aplicación Flutter de **CosechaClima**, un asistente de riesgo agroclimático para pequeños productores de Nicaragua. Desde la versión 2.0 la app es **100 % local**: no necesita servidor, cuenta, URL de API ni archivo de entorno para funcionar. Las parcelas, los umbrales y la bitácora viven en el teléfono.

---

## Qué funciona sin conexión

| Función | Dónde | ¿Necesita internet? |
|---|---|---|
| Semáforo y plan semanal | Teléfono (`MotorLocal`, Dart) | No (usa el último pronóstico, válido hasta 3 días) |
| 540 reglas agronómicas + catálogos | Asset embebido `assets/reglas/paquete_reglas.json` | No |
| Parcelas, umbrales, bitácora | Teléfono (`SharedPreferences`) | No |
| Copia de seguridad / restaurar | JSON copiado al portapapeles | No |
| Pronóstico fresco | Llamada directa a Open-Meteo | Sí, solo para la primera carga o una actualización |
| Cuentas, servidor, Admin Console | Eliminados de la app móvil | No se usan |

El pronóstico se guarda 2 horas y puede mostrarse sin conexión hasta 3 días. También se guarda en el teléfono la última evaluación completa de cada parcela como respaldo.

> Datos meteorológicos: [Open-Meteo.com](https://open-meteo.com/), licencia CC BY 4.0. El plan gratuito es para uso no comercial; la atribución se muestra dentro de la app.

## Requisitos

- Flutter SDK (canal estable)
- Android Studio o VS Code con la extensión Flutter
- Dispositivo o emulador Android/iOS

No hace falta backend, base de datos, archivo `.env` ni `--dart-define`.

## Instalar y ejecutar

```bash
cd mobile
flutter pub get
flutter run
```

Compilar para release:

```bash
flutter build apk --release
# o
flutter build appbundle --release
flutter build ios --release
```

## Datos locales y copia de seguridad

Todo se guarda en el almacenamiento privado de la app:

| Clave | Contenido |
|---|---|
| `onboarding_visto` | Si el tutorial ya se mostró |
| `parcelas_invitado` | Parcelas locales (se conserva la clave histórica para migrar las parcelas del modo invitado anterior) |
| `umbral_local` | Umbrales de riesgo |
| `bitacora_local_v1` | Entradas de la bitácora |
| `forecast_*` | Pronósticos de Open-Meteo en caché |
| `evaluacion_local_*` | Última evaluación completa de cada parcela |

Usá **Mis parcelas → Copia de seguridad** para:

1. copiar un respaldo JSON al portapapeles (guardalo en WhatsApp, correo o un archivo), y
2. restaurarlo más tarde en el mismo teléfono o en uno nuevo.

Restaurar **reemplaza** las parcelas, la bitácora y los umbrales actuales. En el primer arranque la app también migra la copia antigua de parcelas del servidor (`cache_lista_parcelas`) y las parcelas del modo invitado, para que los usuarios existentes no pierdan sus datos.

## Estructura del proyecto

```text
mobile/
|-- lib/
|   |-- core/
|   |   |-- app/                  # Estado del onboarding
|   |   |-- cache/                # Caché de pronóstico y de evaluación
|   |   |-- clima/                # Cliente de Open-Meteo
|   |   |-- config/               # Constantes y centroides de municipios
|   |   |-- local/                # Migración desde la caché del servidor anterior
|   |   |-- motor/                # Motor de 540 reglas y carga del paquete embebido
|   |   |-- network/              # Excepciones de red y timeout
|   |   |-- services/             # Geolocalización y notificaciones locales
|   |-- features/
|   |   |-- parcela/              # Modelo, almacén, asistente, detalle y edición local
|   |   |-- clima/                # Resumen semanal y servicio del motor local
|   |   |-- catalogo/             # Catálogos locales desde el paquete embebido
|   |   |-- umbral/               # Umbrales de riesgo locales
|   |   |-- bitacora/             # Bitácora de campo local
|   |   |-- backup/               # Copia y restauración JSON
|   |   |-- onboarding/           # Splash, tutorial, acerca de, clima de la zona
|   |-- routing/                  # Entrada a la app y rutas sin animación
|   |-- shared/                   # Widgets reutilizables
|-- assets/reglas/paquete_reglas.json
|-- test/
```

## Motor de reglas

- `lib/core/motor/motor_local.dart` es Dart puro y está cubierto por `test/core/motor/motor_local_test.dart`.
- El paquete embebido contiene **540 reglas**, 6 eventos climáticos, 5 cultivos, 3 tipos de suelo y 6 etapas fenológicas.
- El motor evalúa todos los eventos activos del día y elige el nivel de riesgo más severo (Alto / Medio / Bajo / Sin riesgo) con tres acciones recomendadas.
- No hace ninguna llamada de red para calcular el semáforo ni el plan semanal.

## Verificación

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

## Firma del release

`flutter build apk --release` firma con la clave de debug del SDK de Android por defecto, que no sirve para publicar. Generá un keystore privado una sola vez:

```bash
keytool -genkey -v -keystore ~/cosechaclima-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cosechaclima
```

Creá `mobile/android/key.properties` (ignorado por git):

```properties
storePassword=TU_PASSWORD_DEL_KEYSTORE
keyPassword=TU_PASSWORD_DE_LA_CLAVE
keyAlias=cosechaclima
storeFile=/home/TU_USUARIO/cosechaclima-release.jks
```

`android/app/build.gradle.kts` lo detecta automáticamente; sin ese archivo se usan las claves de debug. Guardá el `.jks` y sus contraseñas con respaldo: si los perdés, no vas a poder publicar actualizaciones con la misma identidad.

Verificá la firma:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

## Problemas comunes

| Síntoma | Causa | Solución |
|---|---|---|
| No hay clima fresco | Sin internet | La app muestra el pronóstico en caché (hasta 3 días) o la última evaluación guardada |
| El clima está viejo | La caché venció y no hay conexión | Reconectarse y actualizar |
| Los datos desaparecieron al cambiar de teléfono | El almacenamiento local es por dispositivo | Restaurar el respaldo JSON desde **Copia de seguridad** |
| No llegan notificaciones | Permiso de notificaciones denegado | Habilitarlo en los ajustes de Android/iOS y en **Ajustar mis alertas** |
| El build de Android falla tras actualizar dependencias | Plugins generados obsoletos | `flutter clean && flutter pub get` |

El backend y la Admin Console siguen en el repositorio como código histórico/de referencia, pero la app móvil ya no los llama.
