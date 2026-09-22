<div align="center">
  <img src="docs/assets/cosechaclima-logo.svg" width="250" alt="CosechaClima Logo">
  <br><br>

  ![.NET 10](https://img.shields.io/badge/.NET-10.0-512BD4)
  ![C#](https://img.shields.io/badge/C%23-13-239120)
  ![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B)
  ![SQL Server 2022](https://img.shields.io/badge/SQL_Server-2022-CC2927)
  ![Docker](https://img.shields.io/badge/Docker-Compose-2496ED)
  ![License MIT](https://img.shields.io/badge/license-MIT-green)
</div>

<!-- README-I18N:START -->

[English](./README.md) | **Español**

<!-- README-I18N:END -->

# CosechaClima

**Sistema de alerta agroclimática temprana para pequeños productores de granos básicos en Carazo, Nicaragua.**

Cruza datos climáticos en tiempo real contra un árbol de decisión agronómico para traducir el clima en tres acciones concretas que un productor puede tomar hoy — sin costo, sin conexión constante, sin depender de un técnico presente.

---

## Tabla de contenido

- [El problema](#el-problema)
- [Como funciona](#como-funciona)
- [Arquitectura](#arquitectura)
- [Stack tecnologico](#stack-tecnologico)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Puesta en marcha](#puesta-en-marcha)
- [Seguridad](#seguridad)
- [Costo de infraestructura](#costo-de-infraestructura)
- [Como contribuir](#como-contribuir)
- [Agradecimientos](#agradecimientos)
- [Licencia](#licencia)

---

## El problema

En Carazo, los granos básicos como maíz y frijol ocupan el 62% del área agrícola del departamento. Los pequeños productores toman decisiones críticas de manejo — regar, drenar, proteger del viento — basándose en la observación directa del cielo, sin acceso a pronósticos localizados ni a un técnico agrónomo disponible todos los días.

CosechaClima traduce datos climáticos abiertos en una recomendación accionable de 3 pasos, adaptada al cultivo, la etapa fenológica y el tipo de suelo de cada parcela específica.

## Como funciona

1. El productor registra su parcela: cultivo, etapa fenológica, tipo de suelo y coordenadas GPS.
2. Configura sus propios umbrales de riesgo (mm de lluvia, km/h de viento, días de canícula).
3. El sistema consulta datos climáticos reales de la zona vía Open-Meteo.
4. El **motor de decisiones** evalúa todos los eventos climáticos activos simultáneamente contra un árbol de **216 reglas agronómicas** (180 de eventos de riesgo + 36 de "sin riesgo") y selecciona la alerta con el nivel de riesgo más severo (Alto / Medio / Bajo / Sin riesgo) con 3 acciones recomendadas.
5. El productor registra en su bitácora de campo que acciones completó, y puede compartir un resumen de texto simple.

**Sin cuenta también sirve.** La app abre en un inicio público con el pronóstico de 5 días de la zona (Carazo, o la ubicación del teléfono) y solo pide iniciar sesión al hacer algo privado, como guardar una parcela. Se puede entrar con **Google** (un toque, sin recordar contraseña) o con **correo y contraseña**.

## Arquitectura

```mermaid
flowchart TD
    A["Flutter Mobile App"] -->|"HTTPS + JWT"| B["ASP.NET Core 10 API"]
    B --> C["Motor de Decisiones"]
    C --> D["Arbol de 216 Reglas Agronomicas"]
    B --> E["Open-Meteo API"]
    B --> F["SQL Server 2022"]
    F --> G["ADO.NET - Queries optimizadas con OPENJSON"]
    B --> H["Rate Limiting + JWT Auth con Jti"]
    A -->|"Login con Google"| I["Google Sign-In"]
    B -->|"Valida el ID Token"| I
```

Arquitectura en capas estricta: cada capa solo conoce a la inmediatamente inferior a través de una interfaz. El motor de decisiones, por ejemplo, no sabe si los datos climáticos vienen de Open-Meteo o de cualquier otra fuente; solo conoce `IProveedorClimaticoService`.

## Stack tecnologico

| Capa | Tecnologia | Justificacion |
|---|---|---|
| Backend | ASP.NET Core 10 | LTS vigente, tipado fuerte, rendimiento |
| Base de datos | SQL Server 2022 (Docker) | Developer Edition, gratuita |
| Acceso a datos | ADO.NET con OPENJSON | Control total sobre consultas, batch updates optimizados |
| Autenticacion | JWT Bearer + correo/contraseña (PBKDF2 + salt) + Google Sign-In + Jti | Google Sign-In es gratuito: sin SMS ni servicios de pago |
| Datos climaticos | [Open-Meteo](https://open-meteo.com) | Pronostico real hasta 16 dias, sin API key, gratuito |
| Contenedorizacion | Docker multi-stage (Alpine) | Imagen optimizada, usuario no-root |
| Cliente movil | Flutter | Codigo unico multiplataforma |
| CI/CD | GitHub Actions | Build y test automatizados |

## Estructura del repositorio

```
CosechaClima/
|-- backend/
|   |-- WebApi/                    # API: controladores, DTOs, Program.cs
|   |-- WebApi.Models/             # Entidades de dominio
|   |-- Services/
|   |   |-- WebApi.Interface/      # Contratos de servicio
|   |   |-- WebApi.Implementation/ # Logica de negocio + ADO.NET
|   |-- Scripts/                   # Esquema SQL, seed, reglas JSON
|   |-- Dockerfile                 # Build multi-stage (SDK -> Alpine)
|-- mobile/                        # App Flutter
|-- docs/                          # Documentacion tecnica
|-- compose.yaml                   # Docker Compose (raiz del proyecto)
|-- .env.example                   # Plantilla de variables de entorno (raiz)
|-- .github/workflows/             # Pipelines CI/CD
|-- README.md
```

## Puesta en marcha

Todo el entorno se ejecuta desde la raiz del proyecto con Docker Compose.

**Prerequisitos:** Docker + Docker Compose instalados.

```bash
git clone https://github.com/Abemilek/CosechaClima.git
cd CosechaClima
cp .env.example .env
# Editar .env con tus valores (ver comentarios en .env.example)
docker compose up --build -d
```

Verificacion:

```bash
curl http://localhost:8080/health
```

Esperado: `200 OK` con `Healthy`.

> [!WARNING]
> `DB_SA_PASSWORD` debe cumplir la politica de complejidad de SQL Server: minimo 8 caracteres combinando al menos 3 de 4 categorias (mayusculas, minusculas, digitos, simbolos).

> [!WARNING]
> SQL Server solo aplica `DB_SA_PASSWORD` la primera vez que crea el volumen. Si la cambias despues, `db` queda `unhealthy` con `Login failed for user 'sa'`. En desarrollo: `docker compose down -v && docker compose up --build` (borra los datos).

> [!NOTE]
> `ASPNETCORE_ENVIRONMENT` es `Production` por defecto (Swagger oculto). Para desarrollo local poner `ASPNETCORE_ENVIRONMENT=Development` en `.env` y abrir `http://localhost:8080/swagger`.

> [!NOTE]
> **Google Sign-In es opcional.** Sin Client IDs, la app sigue funcionando con correo y contraseña. Para activarlo ver [docs/google-sign-in-setup.md](docs/google-sign-in-setup.md). La app movil tiene su propio `mobile/.env` (`API_URL` y `GOOGLE_SERVER_CLIENT_ID`).

> [!NOTE]
> `compose.yaml` inicia automaticamente: SQL Server, scripts de esquema y seed, y construye la API con Dockerfile multi-stage. Ver [backend/README.es.md](backend/README.es.md) y [mobile/README.es.md](mobile/README.es.md) para instrucciones detalladas de cada componente.

## Seguridad

- Autenticacion JWT con expiracion configurable y claim `Jti` para unicidad de token.
- Inicio de sesion con Google: el ID Token se valida siempre en el servidor (firma, audiencia, expiracion y correo verificado).
- Contrasenas almacenadas exclusivamente como hash PBKDF2-SHA256 + salt individual por usuario (minimo 8 caracteres). Las cuentas de Google no tienen contraseña local.
- Comparacion de hash en tiempo constante (`CryptographicOperations.FixedTimeEquals`).
- Modo invitado acotado: solo `/api/auth/*`, el pronostico por coordenadas, los catalogos y `/health` son publicos; todo lo demas exige JWT.
- Control de acceso por propietario (ownership) en todos los recursos, derivado del token.
- Rol `Admin` separado para operaciones administrativas, otorgado solo via seed de base de datos.
- Rate Limiting en endpoints de autenticacion (register, login y Google) y en el motor de decisiones.
- Manejador global de errores con estandar RFC 7807 (`ProblemDetails`).
- CORS restringido por lista explicita de origenes permitidos.
- Secretos gestionados por variables de entorno (`.env`), nunca hardcodeados.
- Runtime Docker con imagen Alpine, usuario no-root. Entorno `Production` por defecto.

Detalle completo en [docs/security.md](docs/security.md).

## Costo de infraestructura

**$0.** SQL Server Developer Edition, Open-Meteo, ASP.NET Core y todo el stack son gratuitos para este caso de uso. El proyecto corre completo en una laptop via Docker Compose.

## Como contribuir

Este repositorio usa ramas de feature protegidas contra `main` y [Conventional Commits](https://www.conventionalcommits.org/). Detalle en [CONTRIBUTING.md](CONTRIBUTING.md).

## Agradecimientos

- [Open-Meteo](https://open-meteo.com) por el acceso gratuito a datos meteorologicos de alta resolucion.
- INTA Nicaragua y FAO por las guias tecnicas publicas de manejo de maiz y frijol.
- [OWASP API Security Project](https://owasp.org/www-project-api-security/) como marco de referencia para el endurecimiento de seguridad.

## Licencia

Este proyecto se distribuye bajo licencia MIT -- ver [LICENSE](LICENSE).