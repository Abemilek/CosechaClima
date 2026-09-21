# Google Sign-In -- Guia de configuracion

Como configurar "Continuar con Google" de punta a punta: Google Cloud Console, el backend y la app Flutter. Google Sign-In es **gratuito** y no requiere Firebase ni ningun plan de pago. El flujo completo de autenticacion esta en [authentication.md](./authentication.md).

> [!NOTE]
> Es opcional. Si `GOOGLE_SERVER_CLIENT_ID` queda vacio en la app, el boton de Google se oculta y solo se ofrece correo + contrasena. Los nombres exactos de los menus de Google Cloud Console cambian con el tiempo; los pasos describen el objetivo de cada pantalla.

## Que se necesita

| Credencial | Donde se crea | Donde se usa |
|---|---|---|
| Client ID **Web** | Cloud Console -> credenciales -> ID de cliente de OAuth -> Aplicacion web | Backend: `GOOGLE_CLIENT_ID_WEB`. App: `GOOGLE_SERVER_CLIENT_ID` (mismo valor) |
| Client ID **Android** | Cloud Console -> ID de cliente de OAuth -> Android (paquete + SHA-1) | Backend: `GOOGLE_CLIENT_ID_ANDROID` (recomendado). La app no lo lee: Google lo usa para reconocer la app. |
| Client ID **iOS** | Cloud Console -> ID de cliente de OAuth -> iOS | Backend: `GOOGLE_CLIENT_ID_IOS` (opcional, puede quedar vacio) |

Por que hace falta el Client ID Web aunque la app sea Android: el SDK solo entrega un `idToken` (el que el backend puede verificar criptograficamente) si se le pasa un `serverClientId`. Sin el, devuelve solo un `accessToken`, que el backend no puede validar. Con `serverClientId`, el campo `aud` del token es el Client ID Web, por eso **ese es el obligatorio en el backend**.

> [!IMPORTANT]
> Un Client ID **no es un secreto**: viaja en cada request de OAuth. Lo que nunca debe salir de Google Cloud es el *client secret*, y esta app no lo usa en ningun momento. No lo pegues en `.env` ni en el codigo.

## Paso 1 -- Proyecto y pantalla de consentimiento

1. En [Google Cloud Console](https://console.cloud.google.com/) crea un proyecto (por ejemplo `CosechaClima`).
2. Configura la **pantalla de consentimiento de OAuth**: tipo *Externo*, nombre de la app y correo de soporte. Sin correo de soporte, el inicio de sesion puede fallar con un error generico.
3. Mientras la app este en modo **Prueba**, solo pueden iniciar sesion las cuentas agregadas como *usuarios de prueba*. Agrega las tuyas. Para abrirlo a cualquier persona hay que publicar la app.

## Paso 2 -- Client ID Web

1. Crea un ID de cliente de OAuth de tipo **Aplicacion web**. No necesita origenes ni URIs de redireccion para este flujo.
2. Copia el Client ID (termina en `.apps.googleusercontent.com`). Es el valor de `GOOGLE_CLIENT_ID_WEB` y de `GOOGLE_SERVER_CLIENT_ID`.

## Paso 3 -- Client ID Android

1. Crea un ID de cliente de OAuth de tipo **Android**.
2. **Nombre del paquete:** `ni.edu.unan.cosechaclima` (el `applicationId` de `mobile/android/app/build.gradle.kts`). Debe coincidir exactamente con el de la app que estas ejecutando.
3. **Huella digital SHA-1** del keystore con el que se firma la app:

```bash
# Keystore de debug (el que usa flutter run)
keytool -list -v -keystore ~/.android/debug.keystore \
  -alias androiddebugkey -storepass android -keypass android

# O, desde el proyecto, todas las variantes de una vez
cd mobile/android && ./gradlew signingReport
```

Cada keystore tiene su propio SHA-1: el de debug de cada desarrollador, el de release, y -- si se publica en Google Play con *Play App Signing* -- el que muestra la consola de Play. Cada uno necesita su propio Client ID Android.

> [!WARNING]
> Si el paquete o el SHA-1 no coinciden con la app instalada, Google rechaza el inicio de sesion (ver [Problemas comunes](#problemas-comunes)). Si cambiaste el `applicationId`, hay que crear o actualizar el Client ID Android.

## Paso 4 -- Configurar el backend

En el `.env` de la raiz:

```bash
GOOGLE_CLIENT_ID_ANDROID=<client id android>.apps.googleusercontent.com
GOOGLE_CLIENT_ID_IOS=
GOOGLE_CLIENT_ID_WEB=<client id web>.apps.googleusercontent.com
```

`compose.yaml` los pasa a la API como `GoogleAuth__ClientIds__0/1/2`. Los valores vacios se ignoran. Recrea el contenedor para que tome los cambios:

```bash
docker compose up -d --force-recreate api
```

## Paso 5 -- Configurar la app

En `mobile/.env`:

```bash
API_URL=http://10.0.2.2:8080
GOOGLE_SERVER_CLIENT_ID=<client id web>.apps.googleusercontent.com
```

`GOOGLE_SERVER_CLIENT_ID` es el Client ID **Web**, no el de Android. Como se inyecta en tiempo de compilacion, hay que **detener la app y volver a lanzarla** (un hot restart no basta):

```bash
flutter run --dart-define-from-file=.env
```

## Paso 6 -- Verificar

1. La pantalla de login muestra el boton **Continuar con Google** (si no aparece, `GOOGLE_SERVER_CLIENT_ID` esta vacio).
2. Al tocarlo se abre el selector de cuentas de Google y, al elegir una, la app entra con esa cuenta.
3. En los logs de la API no aparece `ID Token de Google invalido` ni `GoogleAuth:ClientIds no esta configurado`:

```bash
docker compose logs -f api
```

## Problemas comunes

| Sintoma | Causa probable | Solucion |
|---|---|---|
| No aparece el boton de Google | `GOOGLE_SERVER_CLIENT_ID` vacio, o la app no se recompilo despues de editarlo | Completar `mobile/.env` y relanzar con `--dart-define-from-file=.env` |
| Error `ApiException: 10` (`DEVELOPER_ERROR`) al elegir la cuenta | El paquete o el SHA-1 del Client ID Android no coinciden con la app instalada | Revisar el paquete y el SHA-1 del keystore que firma ese build (paso 3) |
| Error `12500` al iniciar sesion | Pantalla de consentimiento incompleta (falta correo de soporte) o cuenta no autorizada | Completar la pantalla de consentimiento; agregar la cuenta como usuario de prueba |
| "Acceso bloqueado" / app no verificada | La app esta en modo Prueba y la cuenta no esta en la lista | Agregarla como usuario de prueba, o publicar la app |
| La app dice que Google no devolvio un `idToken` | Falta `serverClientId`, o se uso el Client ID de Android en vez del Web | Usar el Client ID **Web** en `GOOGLE_SERVER_CLIENT_ID` |
| La API responde `401` "no se pudo validar la cuenta de Google" | El `aud` del token no esta en `GoogleAuth:ClientIds`, el token expiro, o el correo no esta verificado | Verificar que `GOOGLE_CLIENT_ID_WEB` sea el mismo Client ID Web de la app; revisar el log de la API |
| Funciona en debug pero no en release | El SHA-1 del keystore de release no esta registrado | Crear un Client ID Android con ese SHA-1 (ver [mobile/README.md](../mobile/README.md), "Firma del APK") |

> [!NOTE]
> Esta guia cubre Android. La configuracion nativa de iOS (URL scheme, `GoogleService-Info` o equivalente) requiere pasos adicionales que no se documentan aqui.
