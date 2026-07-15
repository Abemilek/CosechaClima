# CosechaClima — Tu semáforo de decisiones climáticas para el campo

**Concurso Multidisciplinario de Aplicaciones Móviles Creativas — 2da Edición**
CUR-Carazo, UNAN-Managua · Eje 7: Cambio Climático

CosechaClima es una aplicación móvil que ayuda a pequeños productores agropecuarios del departamento de Carazo, Nicaragua, a proteger sus cosechas de maíz y frijol frente a eventos climáticos extremos. Ante cada evento meteorológico relevante, la app determina el riesgo para el cultivo y la etapa fenológica del usuario, y le entrega **exactamente 3 acciones prioritarias** mediante un sistema de semáforo (verde / amarillo / rojo).

## Estructura del repositorio

```
CosechaClima/
├── backend/     → API REST en ASP.NET Core 8 + C#, base de datos SQL Server,
│                  motor de decisiones (árbol de 90 reglas) y cliente de NASA POWER.
│                  Ver backend/README.md para detalle técnico completo.
│
├── mobile/      → App cliente en Flutter (Android). En construcción.
│                  Ver mobile/README.md.
│
├── docs/        → Informe del proyecto, capturas de pantalla, diagramas de apoyo.
│                  
│
└── .github/     → Workflows de integración continua (build automático del backend).
```

## Arquitectura general

```
App Flutter (mobile/)  ──HTTP/JSON──>  API ASP.NET Core (backend/)  ──HTTPS──>  NASA POWER
                                              │
                                              ▼
                                        SQL Server (Azure SQL Database)
```

## Cómo correr el proyecto

**Backend:**
```bash
cd backend
dotnet restore
dotnet run --project CosechaClima.Api
```
Instrucciones completas (requisitos, base de datos, endpoints) en [`backend/README.md`](./backend/README.md).

**Mobile:**
Instrucciones en [`mobile/README.md`](./mobile/README.md) (pendiente mientras se inicia el desarrollo de la app).

