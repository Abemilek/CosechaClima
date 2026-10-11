# Plan B: motor en el dispositivo y backend delgado

## Problema que resuelve

Antes, todo cálculo pasaba por el servidor: sin conexión (o con el servidor caído) la app mostraba datos viejos o un error, y todos los usuarios compartían la IP y la cuota diaria de Open-Meteo. Para productores con conectividad irregular eso es lo contrario de lo que necesitan.

## Qué se hace dónde

| Responsabilidad | Dónde | Funciona sin conexión |
|---|---|---|
| Semáforo de riesgo y plan semanal | **Teléfono** (`MotorLocal`, Dart) | Sí, con el último pronóstico descargado (hasta 3 días) |
| Reglas agronómicas (540) y catálogos | **Embebidas** en la app + actualización por `GET /api/reglas/paquete` | Sí, desde el primer uso |
| Pronóstico | Open-Meteo, **directo desde el teléfono** | Copia local (2 h de frescura) |
| Umbrales del productor | Servidor + copia local y cola de pendientes | Sí |
| Cuentas, sesiones, parcelas, bitácora | **Servidor** (PostgreSQL) | Lectura con caché; **escritura requiere conexión** |
| Edición de reglas, usuarios, auditoría de alertas | **Servidor** + Admin Console | No aplica |

## Flujo de una consulta de parcela

1. La app intenta refrescar la parcela desde el servidor (si falla por red, sigue con la local).
2. Lee los umbrales (servidor → copia local → valores por defecto).
3. `MotorLocalService` obtiene la serie de clima (copia fresca, o Open-Meteo; si falla, copia de hasta 3 días) y la pasa a `MotorLocal` junto con las reglas.
4. Muestra el resultado. Con cuenta, avisa en segundo plano a `PUT /api/alertas/parcela/{id}` qué evento detectó (el servidor pone el texto desde su propia regla), para que el panel de auditoría siga funcionando.

## Reglas actualizables sin republicar la app

`GET /api/reglas/paquete` devuelve catálogos + reglas activas con una `version` (SHA-256 truncado del contenido canónico). La app envía `If-None-Match`; si nadie editó nada, `304` sin cuerpo. Un admin que edita una regla en el panel invalida la caché del servidor y la nueva versión llega a los teléfonos en la siguiente revisión (como máximo cada 6 h). El paquete embebido se generó con la misma función de versión, así que un servidor sin cambios responde `304` desde el primer arranque (verificado: el hash calculado en C# coincide con el del asset).

## Diferencias deliberadas respecto al motor del servidor

- **Canícula con historial real**: el servidor solo detectaba canícula si la app había guardado N días de datos (rara vez). Ahora la ventana usa los `past_days` de Open-Meteo, así que se detecta desde el primer día y también en el resumen semanal.
- **"Hoy" local**: se calcula con la fecha del teléfono (antes, la del servidor, que en UTC cambia de día a las 18:00 en Nicaragua).

## Licencia de Open-Meteo (importante)

La API gratuita es para **uso no comercial**, con atribución **CC BY 4.0** y una cuota diaria por IP. La app muestra la atribución ("Datos meteorológicos: Open-Meteo.com (CC BY 4.0)"). Llamar desde cada teléfono reparte la cuota entre usuarios. **Si CosechaClima pasa a uso comercial hay que contratar su plan de pago.** Consulta los términos vigentes en open-meteo.com antes de publicar.

## Lo que NO está hecho (siguiente fase)

1. **Escritura sin conexión para parcelas y bitácora.** Hoy se leen sin conexión (caché) pero crear/editar requiere servidor (salvo umbrales y el modo invitado, que ya tenían cola/almacenamiento local). Diseño propuesto: id generado en el cliente (UUID) + tabla de operaciones pendientes + `POST /api/sync` idempotente con resolución "gana el último cambio", y almacén local con SQLite (`drift`/`sqflite`) cuando el volumen lo justifique. Hoy se usa `shared_preferences`, suficiente para decenas de parcelas.
2. **Notificaciones push (FCM).** Las alertas siguen siendo notificaciones locales que se evalúan al abrir la app. FCM es gratuito pero necesita proyecto de Firebase (`google-services.json`), el paquete `firebase_messaging` y un proceso en el servidor que evalúe y envíe; no se agregó para no meter configuración que no se puede probar sin tus credenciales.
3. Retirar los endpoints legados `/api/motor/*` y `/api/clima/actualizar` cuando no queden apps antiguas.

## Verificación realizada y pendiente

| Parte | Estado |
|---|---|
| Esquema, migraciones, seeds y aplicación de reglas | **Ejecutado** en PostgreSQL 16 real (540 reglas; el re-aplicado no pisa ediciones) |
| Script `db-init/01-roles.sh` | **Ejecutado** contra PostgreSQL 16 |
| Backend C# | **Compila** con .NET 10 contra ASP.NET Core real; Npgsql, JwtBearer y Swagger se sustituyeron por stubs porque NuGet no era accesible → **falta `dotnet build` y probar contra la base real** |
| Hash de versión del paquete de reglas | **Verificado** C# = asset |
| Admin Console | `tsc` y `vite build` **OK**; no probado el flujo de cookie contra la API |
| App Flutter | Sintaxis verificada con parser de Dart; **no se pudo ejecutar `flutter analyze`, `dart format` ni los tests** (no hay SDK de Flutter accesible). Antes de subir a git: `dart format .`, `flutter analyze --fatal-infos`, `flutter test` |
| Docker Compose | `compose.yaml` validado como YAML; **no se levantó con Docker** |
