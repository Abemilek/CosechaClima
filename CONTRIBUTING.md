# Contribuir a CosechaClima

Gracias por sumarte al proyecto. Esta guía cubre lo mínimo que necesitás saber para contribuir sin fricciones — no es un tratado, son las reglas del juego que ya venimos usando.

## Antes de empezar

- La documentación técnica completa vive en [`docs/`](./docs/) — empezá por [`docs/getting-started.md`](./docs/getting-started.md) para levantar el proyecto.
- Si sos del equipo de Flutter, andá directo a [`docs/mobile-integration-guide.md`](./docs/mobile-integration-guide.md).
- `main` está protegida — todo cambio entra por Pull Request, nunca con push directo.

## Flujo de trabajo

1. Creá una rama desde `main` actualizado.
2. Hacé tus cambios, con commits siguiendo la convención de abajo.
3. Si tu cambio afecta algún endpoint (nueva ruta, campo agregado/quitado, comportamiento distinto), **actualizá la documentación correspondiente en `docs/` en el mismo PR** — no en uno aparte, no "después". El código y su documentación se revisan juntos.
4. Abrí el Pull Request contra `main`.
5. Esperá revisión antes de mergear.

## Convención de nombres de rama

```
tipo/descripcion-corta-en-ingles
```

| Tipo | Uso |
|---|---|
| `feat/` | Funcionalidad nueva |
| `fix/` | Corrección de un bug |
| `refactor/` | Cambio de código sin alterar comportamiento externo |
| `docs/` | Solo documentación |
| `test/` | Solo pruebas |
| `chore/` | Configuración, dependencias, tareas de mantenimiento |

Ejemplos reales del proyecto: `fix/authorization-and-route-binding`, `feat/error-handling-rate-limiting-health`, `refactor/migrate-open-meteo`.

## Convención de commits

Seguimos [Conventional Commits](https://www.conventionalcommits.org/es/v1.0.0/):

```
tipo(alcance): descripción breve en presente

feat(parcelas): add ownership validation to update endpoint
fix(bitacora): correct route parameter binding
docs: update API endpoint table
test(motor): add unit tests for canicula detection
chore(docker): add healthcheck to api service
```

El `alcance` entre paréntesis es opcional pero recomendado — ayuda a ubicar rápido qué parte del sistema tocó el commit.

## Antes de abrir el Pull Request

- [ ] `dotnet build` compila sin errores ni warnings nuevos.
- [ ] Si agregaste o cambiaste un endpoint, actualizaste `docs/api-reference.md` (y `docs/mobile-integration-guide.md` si afecta al flujo que usa la app).
- [ ] Si el cambio es de seguridad o autorización, revisaste que `docs/security.md` siga reflejando la realidad.
- [ ] Probaste el cambio manualmente contra Swagger, al menos el caso feliz y un caso de error.

## Reportar un problema

Usá los Issues del repositorio. Si es un bug, incluí: endpoint afectado, qué mandaste, qué esperabas, qué obtuviste. Con esos cuatro datos se resuelve casi cualquier cosa rápido.
