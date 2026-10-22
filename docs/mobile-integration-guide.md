# Mobile Integration Guide

> La app móvil v2 es **100 % local**. Esta guía describe el flujo vigente. La
> integración con el backend ASP.NET Core quedó como referencia histórica; el
> backend no es necesario para usar la app. Ver [local-first.md](./local-first.md).

## Requisitos

- Flutter SDK (canal estable)
- Dispositivo o emulador Android/iOS
- No hace falta `.env`, `API_URL`, backend ni base de datos

## Ejecutar

```bash
cd mobile
flutter pub get
flutter run
```

## Primer arranque

1. `SplashScreen` muestra la portada.
2. `TutorialScreen` explica el semáforo, el plan semanal y la bitácora. Se
   muestra una sola vez (`onboarding_visto`).
3. `ParcelaListScreen` queda como inicio permanente.
4. Si no hay parcelas, el estado vacío invita a crear la primera.

No hay login, cuentas, JWT ni roles.

## Crear una parcela

1. Elegir cultivo (catálogo local).
2. Elegir municipio o usar GPS.
3. Elegir fecha de siembra y etapa (o dejar que se calcule por fecha).
4. Elegir tipo de suelo.
5. Confirmar área y guardar.

La parcela se guarda en `parcelas_invitado` y queda disponible sin conexión.

## Detalle de parcela

`ParcelaLocalDetailScreen` tiene tres pestañas:

| Pestaña | Contenido |
|---|---|
| Inicio | Semáforo de hoy, clima, acciones, ficha y botón para guardar en bitácora |
| Cuaderno | Entradas locales de esa parcela; permite marcar acciones |
| Semana | Plan de 7 días con el día más crítico |

El menú permite editar la parcela, ajustar alertas, ver “Acerca de” y eliminar.
Eliminar borra también las entradas de bitácora y la caché de esa parcela.

## Motor y datos

- El motor se ejecuta con `MotorLocalService.evaluar(...)`.
- Usa `OpenMeteoClient` directo; la caché se guarda 2 horas y sirve hasta 3
  días sin conexión.
- Si el pronóstico venció y no hay red, se usa `EvaluacionLocalCache`.
- Los umbrales se leen de `UmbralService.obtenerParaMotor()`.
- Las reglas y catálogos salen de `ReglasRepository` (asset embebido).

## Bitácora local

`BitacoraService` guarda las entradas en `bitacora_local_v1`. Cada entrada
tiene id local, parcela, fecha, evento, nivel de riesgo, tres acciones y notas.
`marcarAccion` actualiza el estado; `obtenerResumen` genera un texto para
compartir.

## Copia de seguridad

`LocalBackupService.exportar()` devuelve un JSON con parcelas, umbral y
bitácora. `importar()` valida el formato y reemplaza los datos locales. La
pantalla `CopiaSeguridadScreen` ofrece copiar, ver, restaurar desde el
portapapeles o pegar manualmente.

## Pruebas

```bash
cd mobile
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test
```

Cobertura actual: motor de 540 reglas, caché de clima, parcelas locales,
umbrales y migración, bitácora y respaldo.

## Historia

La guía anterior describía login contextual, JWT, refresh tokens y llamadas a
`/api/...`. Ese flujo se retiró de la app móvil al adoptar el Plan A. Los
documentos del backend se conservan para referencia:

- [authentication.md](./authentication.md)
- [api-reference.md](./api-reference.md)
- [plan-b-offline-first.md](./plan-b-offline-first.md) (histórico)
