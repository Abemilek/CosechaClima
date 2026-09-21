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
- [Modo invitado y autenticacion](#modo-invitado-y-autenticacion)
- [Seguridad](#seguridad)
- [Integracion con la API](#integracion-con-la-api)
- [Compilacion para release](#compilacion-para-release)
- [Problemas comunes](#problemas-comunes)

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

# Google Sign-In (opcional): Client ID de tipo WEB, no el de Android
GOOGLE_SERVER_CLIENT_ID=
```

| Variable | Obligatoria | Descripcion |
|---|---|---|
| `API_URL` | Si | Base de la API. **Solo dominio y puerto, sin rutas** |
| `GOOGLE_SERVER_CLIENT_ID` | No | Client ID Web de Google Cloud. Si esta vacio, la app oculta el boton "Continuar con Google" y solo ofrece correo y contrasena. Ver [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |

> [!NOTE]
> `10.0.2.2` es el alias del emulador Android para el localhost de la maquina host. Para dispositivos fisicos, usar la IP local real.

> [!IMPORTANT]
> `API_URL` **no debe llevar ruta**. La app arma cada peticion como `API_URL` + `/api` + el endpoint. Un valor como `https://host/swagger/index.html` o `https://host/api` hace que todas las pantallas fallen con `Error inesperado (404)`.

> [!NOTE]
> Android 9+ bloquea `http://` por defecto. El manifest de **debug** lo permite para desarrollo local (por ejemplo `http://10.0.2.2:8080`); los builds de release exigen `https://`.

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

Como los valores se resuelven en **compilacion**, cada cambio en `.env` exige detener la app y volver a lanzarla; un hot reload o hot restart no lo aplica.

> [!WARNING]
> No existe fallback a ninguna URL por defecto. Siempre crear el archivo `.env` antes de ejecutar. El archivo `.env` no debe subirse a control de versiones.

## Estructura del proyecto

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

## Modo invitado y autenticacion

La app **no obliga a tener cuenta**. El onboarding se muestra una sola vez (primer arranque) y despues se entra siempre al inicio:

| Estado | Pantalla de inicio |
|---|---|
| Sin sesion (invitado) | `PublicHomeScreen`: pronostico de 5 dias de la zona |
| Con sesion | `ParcelaListScreen` (productor) o `AdminHomeScreen` (rol Admin) |

| Area | Invitado | Con cuenta |
|---|---|---|
| Onboarding | Si | Si |
| Pronostico de la zona (Carazo aproximado, o "Usar mi ubicacion") | Si | Si |
| Parcelas, umbrales, clima de parcela, semaforo, bitacora | No, pide iniciar sesion | Si |
| Panel de administracion | No | Solo rol Admin |

**La sesion se pide en un unico punto.** Al tocar "Mis parcelas" en el inicio publico se abre un login contextual (`mostrarLoginContextual`) que explica el motivo. Si sale bien, la app continua a lo que el usuario queria hacer; si cancela, se queda donde estaba.

**Formas de iniciar sesion:**

- **Continuar con Google** (`AuthService.loginConGoogle`): el SDK devuelve un `idToken` y la app lo manda a `POST /api/auth/google`. Requiere `GOOGLE_SERVER_CLIENT_ID` y que el paquete y el SHA-1 esten registrados en Google Cloud.
- **Correo y contrasena** (`EmailAuthScreen`): pestanas "Soy nuevo" (`POST /api/auth/register`) y "Ya tengo cuenta" (`POST /api/auth/login`). Correo con formato valido y contrasena de al menos 8 caracteres.

Las tres respuestas traen `{ token, nombre, email, fotoUrl, esAdmin }`. Si el backend responde `401` en un endpoint protegido (token vencido), `AuthViewModel` cierra la sesion y la app vuelve al inicio publico con el aviso "Tu sesión expiró. Volviste al modo público."

`AuthViewModel` expone `estado` (`desconocido`, `autenticado`, `invitado`), `estaAutenticado`, `esAdmin` y `onboardingVisto`. Ver [../docs/mobile-integration-guide.md](../docs/mobile-integration-guide.md) para el detalle del flujo.

## Seguridad

### Almacenamiento de token JWT

Los tokens JWT se almacenan usando `flutter_secure_storage`, que utiliza:

- **Android:** EncryptedSharedPreferences (AES-256)
- **iOS:** Keychain Services

> [!WARNING]
> Nunca almacenar tokens en `SharedPreferences` ni en variables de texto plano. Siempre usar `flutter_secure_storage`.

`SharedPreferences` solo guarda datos **no sensibles** para mostrar la interfaz: nombre, correo, URL de la foto y el indicador de onboarding visto. Al cerrar sesion se borran el token y esos datos, y se cierra la sesion de Google.

El Client ID de Google que lleva la app no es un secreto; el *client secret* nunca se usa ni se incluye en la app.

### Cliente HTTP y manejo de tokens

La clase `ApiClient` gestiona:

- Inyeccion automatica del header `Authorization: Bearer <token>` en todas las peticiones autenticadas.
- Traduccion de errores HTTP a excepciones tipadas (`ApiException`, `NetworkException`, `TimeoutApiException`).
- Terminacion automatica de sesion ante respuestas 401 (token expirado): la app vuelve al modo publico.
- Lectura del mensaje de error desde `title` o `mensaje` segun el endpoint.

## Integracion con la API

La app se comunica con el backend via endpoints REST. Sin cuenta usa solo `GET /api/clima/pronostico` (publico). Con cuenta, el flujo tipico para ver el estado de riesgo de una parcela:

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

En release, `API_URL` debe ser `https://`: el trafico `http://` solo esta permitido en el manifest de debug.

### Firma del APK (obligatorio antes de publicar v1.0)

Por defecto, `flutter build apk --release` firma con la **clave de debug**
del SDK de Android. Esa clave es pública y compartida por todas las
instalaciones del SDK, así que cualquiera puede re-firmar el APK y
suplantar la app. Para un release publicado hay que generar un keystore
propio una sola vez:

```bash
keytool -genkey -v -keystore ~/cosechaclima-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 -alias cosechaclima
```

Luego creá `mobile/android/key.properties` (ya está en `.gitignore`, no
se versiona):

```properties
storePassword=LA_PASSWORD_DEL_KEYSTORE
keyPassword=LA_PASSWORD_DE_LA_CLAVE
keyAlias=cosechaclima
storeFile=/home/TU_USUARIO/cosechaclima-release.jks
```

`android/app/build.gradle.kts` detecta ese archivo automáticamente: si
existe firma con tu keystore, si no se cae a las claves de debug para que
`flutter run --release` siga funcionando en desarrollo.

> [!CAUTION]
> Guardá el `.jks` y sus contraseñas en un lugar seguro y con respaldo.
> Si los perdés, no vas a poder publicar actualizaciones de la app
> firmadas con la misma identidad — Android las rechaza como si fueran
> de otro desarrollador.

Verificá con qué clave quedó firmado el APK:

```bash
keytool -printcert -jarfile build/app/outputs/flutter-apk/app-release.apk
```

Si el propietario dice `CN=Android Debug`, el keystore no se tomó.

> [!IMPORTANT]
> Google Sign-In reconoce la app por su paquete y el **SHA-1 del keystore que la firma**. Cada keystore (debug, release y, si se publica en Google Play con Play App Signing, el de Play) necesita su propio Client ID de tipo Android en Google Cloud; si no, el login con Google falla en ese build con `ApiException: 10`. Ver [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md).

### Identificador de aplicación

El `applicationId` es `ni.edu.unan.cosechaclima`. Antes era
`com.example.mobile`: el prefijo `com.example` está reservado para
ejemplos y Google Play rechaza cualquier APK que lo use. Este valor es
**permanente** una vez publicada la app — cambiarlo después obliga a
publicar una app nueva desde cero.

El Client ID Android de Google Cloud debe usar este mismo paquete. Si lo cambias, hay que crear o actualizar ese Client ID.

## Problemas comunes

| Sintoma | Causa probable | Solucion |
|---|---|---|
| `Error inesperado (404)` en el pronostico, el login y el registro | `API_URL` tiene una ruta de mas (`/swagger/...`, `/api`) o apunta a otro servicio | Dejar solo dominio y puerto, y relanzar la app |
| La app no arranca y lanza `API_URL is required` | `mobile/.env` vacio o no se paso `--dart-define-from-file=.env` | Completar `API_URL` y ejecutar `flutter run --dart-define-from-file=.env` |
| Cambie el `.env` pero la app sigue igual | Los valores se resuelven al compilar | Detener la app y volver a lanzarla |
| No aparece "Continuar con Google" | `GOOGLE_SERVER_CLIENT_ID` vacio | Completarlo con el Client ID Web y relanzar |
| Google falla con `ApiException: 10` | Paquete o SHA-1 no coinciden con el Client ID Android | Ver [../docs/google-sign-in-setup.md](../docs/google-sign-in-setup.md) |
| `Cleartext HTTP traffic not permitted` | Build de release contra una URL `http://` | Usar `https://` en release; en debug el manifest ya lo permite |
| Al crear la cuenta con un correo **nuevo** dice "Ya existe un registro con esos mismos datos" | La base fue creada con una restriccion `UNIQUE` comun sobre `GoogleUid` (solo admite un `NULL`) | Recrear la base con el `BD-CosechaClima.sql` actual (`docker compose down -v`). Si el mensaje es "ya existe una cuenta con este correo", simplemente iniciar sesion |