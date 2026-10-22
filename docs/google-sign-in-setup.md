# Google Sign-In -- Guia de configuracion

> [!IMPORTANT]
> Documento del **backend/stack histórico**. La app móvil v2 es 100 % local y
> no usa esta API. Para la app vigente ver [local-first.md](./local-first.md).


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

## Paso 5 -- App móvil (histórico)

La app móvil v2 **no usa Google Sign-In**, cuentas ni `mobile/.env`. Este paso
ya no aplica. La configuración de Google descrita arriba solo sirve si se
reactiva el backend/Admin Console histórico.

> [!NOTE]
> Esta guia cubre Android. La configuracion nativa de iOS (URL scheme, `GoogleService-Info` o equivalente) requiere pasos adicionales que no se documentan aqui.
