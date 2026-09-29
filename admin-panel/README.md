# CosechaClima -- Panel administrativo

Panel web de administración de CosechaClima. La app móvil de Flutter es **exclusivamente para productores**: aunque una cuenta tenga el rol `Admin`, la app no muestra pantallas administrativas (muestra una pantalla de redirección). Toda la gestión del sistema —usuarios, reglas de alerta y auditoría de alertas— vive acá y en los endpoints protegidos con `[Authorize(Roles = "Admin")]` del backend.

SPA estática: React 18 + TypeScript + Vite, sin framework de UI y sin librerías de animación (bundle chico, render inmediato en conexiones lentas).

---

## Contenido

- [Qué se puede hacer acá](#qué-se-puede-hacer-acá)
- [Ejecutar con Docker (recomendado)](#ejecutar-con-docker-recomendado)
- [Ejecutar localmente sin Docker](#ejecutar-localmente-sin-docker)
- [Variables de entorno](#variables-de-entorno)
- [Scripts de npm](#scripts-de-npm)
- [Endpoints que consume](#endpoints-que-consume)
- [Seguridad](#seguridad)
- [CI](#ci)
- [Estructura del proyecto](#estructura-del-proyecto)

---

## Qué se puede hacer acá

| Sección | Qué hace |
|---|---|
| **Usuarios** | Lista todos los usuarios, busca por nombre o correo, otorga o quita el rol `Admin` y activa o desactiva cuentas. |
| **Reglas de alerta** | Lista las reglas del árbol agronómico, filtra por cultivo / suelo / evento / etapa, edita nivel de riesgo + las 3 acciones + descripción, y activa o desactiva una regla. |
| **Auditoría de alertas** | Últimas alertas calculadas por el motor de decisiones, con filtro por nivel de riesgo. Lectura: no se editan alertas ya emitidas. |

Dos acciones están bloqueadas a propósito, y el backend las rechaza aunque se intente bypasear el panel: un administrador no puede quitarse su propio rol ni desactivar su propia cuenta (te dejarías sin acceso).

---

## Ejecutar con Docker (recomendado)

El panel es un servicio más de `compose.yaml`, así que no hay nada que instalar acá. Desde la **raíz** del repositorio:

```bash
cp .env.example .env
# editá .env con tus valores (ver .env.example)
docker compose up --build -d
```

Levanta tres servicios: `db` (SQL Server + schema/seed), `api` (el backend, puerto 8080) y `admin-panel` (este panel, puerto 8080 interno → **5174** en el host).

- Panel: <http://localhost:5174>
- Verificación de que la API está sana: `curl http://localhost:8080/health`

**Credenciales del admin.** Se crean en el primer arranque a partir de `ADMIN_SEED_EMAIL` / `ADMIN_SEED_PASSWORD` del `.env` raíz. Si la contraseña no está definida o es insegura (menos de 8 caracteres, `CAMBIAME`, `password`), el backend genera una aleatoria y la muestra **una sola vez** en el log del contenedor:

```bash
docker compose logs api | grep -i admin
```

**Si la API no está en `http://localhost:8080`**, cambiá `ADMIN_PANEL_API_URL` en el `.env` raíz y **reconstruí** la imagen: la URL se hornea en el build porque el panel es estático.

```bash
docker compose build admin-panel
docker compose up -d admin-panel
```

Para ver los logs del panel: `docker compose logs admin-panel`.

---

## Ejecutar localmente sin Docker

Requiere Node 20+ y la API corriendo en `http://localhost:8080` (podés levantarla sola con Docker, o con `dotnet run` siguiendo [`backend/README.md`](../backend/README.md)).

```bash
cd admin-panel
npm install
cp .env.example .env      # VITE_API_URL=http://localhost:8080
npm run dev
```

- Panel: <http://localhost:5173> (Vite recarga solo al guardar cambios)

**CORS:** el backend solo acepta orígenes de la lista `Cors__AllowedOrigins`. El puerto 5173 es el que usa Vite, distinto del 5174 de Docker, así que agregalo en el `.env` raíz y reiniciá la API:

```bash
ADMIN_PANEL_ORIGIN=http://localhost:5173
# o, si CORS_ALLOWED_ORIGIN está vacío:
CORS_ALLOWED_ORIGIN=http://localhost:5173
```

```bash
docker compose up -d api     # o dotnet run, desde backend/
```

Si el navegador se queja de CORS, es esto: el backend nunca recibe la petición, el panel no puede avisarte de nada más.

Para probar el build de producción tal como se sirve en Docker:

```bash
npm run build      # genera dist/
npm run preview    # sirve dist/ localmente
```

---

## Variables de entorno

Solo una, y se lee **en tiempo de build** (Vite las incrusta en el bundle):

| Variable | Default | Para qué |
|---|---|---|
| `VITE_API_URL` | `http://localhost:8080` | URL base de la API. Sin barra final. Con Docker la inyecta `compose.yaml` desde `ADMIN_PANEL_API_URL`. |

`admin-panel/.env` está en `.gitignore`: nunca se commitea.

---

## Scripts de npm

| Script | Qué hace |
|---|---|
| `npm run dev` | Servidor de desarrollo de Vite en el puerto 5173, con recarga en caliente. |
| `npm run build` | `tsc -b && vite build` — verifica tipos y genera `dist/`. |
| `npm run preview` | Sirve localmente el `dist/` ya compilado. |

No hay linter ni tests configurados: el typecheck de `tsc -b` es lo que corre en CI.

---

## Endpoints que consume

Todos del backend (`docs/api-reference.md` tiene el detalle completo). Los marcados como admin exigen rol `Admin`:

| Método y ruta | Uso en el panel |
|---|---|
| `POST /api/auth/login` | Login. El panel usa el mismo endpoint que la app móvil y **rechaza** el login si la respuesta no trae `esAdmin`. |
| `GET /api/admin/usuarios` | Listado de usuarios. |
| `PUT /api/admin/usuarios/{id}/rol` | Otorgar / quitar rol `Admin`. |
| `PUT /api/admin/usuarios/{id}/estado` | Activar / desactivar la cuenta. |
| `GET /api/reglas` | Listado de reglas de decisión. |
| `PUT /api/reglas/{id}` | Editar nivel de riesgo y acciones. |
| `PUT /api/reglas/{id}/activa` | Activar / desactivar la regla. |
| `GET /api/admin/alertas?limite=` | Auditoría de alertas recientes (tope 500 en el backend). |
| `GET /api/catalogos/cultivos` · `tipos-suelo` · `eventos-climaticos` · `etapas-fenologicas` | Nombres para mostrar en la tabla de reglas. |

---

## Seguridad

- **El backend es la autoridad.** Todos los endpoints administrativos requieren rol `Admin` en el token; ocultar botones en el panel no es la protección.
- **El rol `Admin` no se puede conseguir desde afuera.** Ni el registro público ni Google Sign-In lo otorgan: llega por el seed del primer arranque o por otro administrador desde este panel.
- **Sesión.** Solo se guarda el JWT en `localStorage` (clave `cosechaclima_admin_token`) y el nombre/correo de la sesión. Si cualquier pedido devuelve `401`, el token se borra y se vuelve al login.
- **Errores.** `api.ts` transforma errores de red y respuestas no-OK en mensajes legibles; nunca se muestran tokens ni contraseñas.

---

## CI

[`Admin Panel CI`](../../.github/workflows/admin-panel-ci.yml) corre en cada push y PR a `main` que toquen `admin-panel/`: `npm ci` con caché de npm y `npm run build` (typecheck + build de Vite), verificando que se genere `dist/index.html`. Equivale a lo que hace `Mobile CI` con `flutter analyze`.

---

## Estructura del proyecto

```
admin-panel/
|-- src/
|   |-- main.tsx           # punto de entrada
|   |-- App.tsx            # shell: login o sidebar + vista activa
|   |-- LoginPage.tsx      # login con email y contraseña
|   |-- UsuariosPage.tsx   # gestión de usuarios y roles
|   |-- ReglasPage.tsx     # editor de reglas de alerta
|   |-- AlertasPage.tsx    # auditoría de alertas
|   |-- components.tsx     # pills de riesgo/estado + modal de confirmación
|   |-- api.ts             # cliente fetch, manejo de token y tipos (DTOs del backend)
|   |-- styles.css         # estilos propios, sin transitions ni @keyframes
|   `-- vite-env.d.ts
|-- Dockerfile             # build Node -> nginx con los archivos estáticos
|-- nginx.conf             # SPA fallback a index.html + caché de assets
|-- .env.example           # VITE_API_URL
|-- index.html
|-- package.json
`-- vite.config.ts
```

---

Documentación general del proyecto: [`README.md`](../README.md) · [`docs/`](../docs/) · [`CONTRIBUTING.md`](../CONTRIBUTING.md).
