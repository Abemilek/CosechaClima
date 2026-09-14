# CosechaClima — Landing page

## Desarrollo local

```bash
npm install
npm run dev
```

Abre en `http://localhost:4321`.

## Build de producción (lo que corre el workflow)

```bash
npm run build
npm run preview   # para revisar el build antes de pushear
```

## Despliegue

Automático: cualquier `push` a `landing-page` dispara `.github/workflows/deploy-landing.yml`, que compila con Astro y publica a GitHub Pages. No requiere PR ni pasos manuales.

URL una vez configurado `Settings → Pages → Source: GitHub Actions`:
`https://abemilek.github.io/CosechaClima/`
