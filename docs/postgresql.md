# PostgreSQL

> [!IMPORTANT]
> Documento del **backend/stack histórico**. La app móvil v2 es 100 % local y
> no usa esta API. Para la app vigente ver [local-first.md](./local-first.md).


Decisiones, convenciones y guía de operación de la base de datos de CosechaClima.

## Por qué PostgreSQL

| | SQL Server (antes) | PostgreSQL 18 (ahora) |
|---|---|---|
| Licencia en producción | La edición **Developer** solo es para desarrollo y pruebas, no se puede usar en producción. **Express** sí, pero con límite de tamaño de base | Licencia PostgreSQL: libre, uso comercial permitido, sin límite de tamaño |
| Docker | Requiere aceptar el EULA de Microsoft | Imagen oficial `postgres`, sin EULA |
| Rol de aplicación | `sa` (superusuario) era lo que usaba el compose | Rol propio sin privilegios de superusuario |
| Hosting gestionado | Más caro | Disponible en prácticamente todos los proveedores |

Versión elegida: **PostgreSQL 18** (versión mayor vigente). El proyecto no depende de nada específico de la 18, así que 16 y 17 también funcionan.

## ¿ORM o SQL puro? Decisión: SQL puro con Npgsql

La decisión depende del caso, no es una regla universal. Para CosechaClima se mantiene **SQL explícito con Npgsql** (sin EF Core ni Dapper):

- **Ya estaba hecho así** y funciona: ~12 servicios con consultas simples (CRUD por clave, 4 upserts, 1 batch). Reescribir todo a un ORM sería la parte más grande y riesgosa del cambio, sin mejorar nada visible.
- **Las consultas que importan son específicas de PostgreSQL**: `INSERT ... ON CONFLICT DO UPDATE` (upsert atómico), `jsonb_to_recordset` (batch en una sola sentencia), `FOR UPDATE` (rotación de refresh tokens), `pg_advisory_lock` (migraciones). Con un ORM acabarías escribiendo SQL crudo igualmente.
- **Control de rendimiento y de índices**: con tablas pequeñas y consultas predecibles, el SQL explícito evita sorpresas (consultas N+1, joins generados).
- **Menos dependencias**: un solo paquete (Npgsql).
- **Costo real**: no hay verificación de las consultas en compilación, y hay que mapear columnas a mano (por ordinal). Mitigación: constantes `Columnas...` junto a cada `MapX`, y pruebas de integración contra un PostgreSQL real cuando el equipo las agregue.

**Cuándo reconsiderarlo:** si el modelo crece (decenas de tablas, relaciones y filtros dinámicos), EF Core con `Npgsql.EntityFrameworkCore.PostgreSQL` empieza a rendir. Un paso intermedio barato es **Dapper**, que quita el código de mapeo conservando el SQL. Es una opinión de ingeniería, no un hecho medido en este proyecto.

La documentación oficial de Npgsql indica usar `NpgsqlDataSource` (disponible desde Npgsql 7) como punto de entrada: es seguro entre hilos, representa el pool de conexiones y se crea una vez. `ConnectionBD` lo envuelve como singleton.

## Convenciones del esquema

Basadas en la documentación de PostgreSQL y en la página [Don't Do This](https://wiki.postgresql.org/wiki/Don%27t_Do_This) del wiki oficial:

- **Nombres** en `snake_case` sin comillas (`fecha_siembra`, `tipos_suelo`). PostgreSQL pliega a minúsculas los identificadores sin comillas; usar `PascalCase` obligaría a poner comillas en todas partes.
- **Claves** con `GENERATED ALWAYS AS IDENTITY` (estándar SQL), no `serial`.
- **Instantes** (`fecha_registro`, `fecha`, `creado_en`...) en **`timestamptz`**, nunca `timestamp`. Fechas puras (`fecha_siembra`) en `date`; la hora diaria del SMS en `time`.
- **Texto** como `text` + `CHECK (char_length(...) <= n)` cuando hay un límite de negocio, en vez de `varchar(n)`.
- **Dinero/medidas**: `numeric(p,s)` con precisión explícita.
- **Integridad en la base, no solo en la API**: `CHECK` de niveles de riesgo válidos, rangos de latitud/longitud, `email = lower(email)`, credenciales coherentes con el proveedor (email vs Google).
- **Índices en claves foráneas.** PostgreSQL **no** los crea automáticamente (a diferencia de la clave primaria o `UNIQUE`); sin ellos, borrar o actualizar la fila referenciada recorre toda la tabla hija. Ver `001_esquema_inicial.sql` (`ix_parcelas_usuario_activas`, `ix_bitacora_usuario_fecha`, `ix_refresh_*`...). Los catálogos (3–6 filas) no los necesitan.
- **Índices parciales** donde encajan: `WHERE activa` en parcelas, `WHERE google_uid IS NOT NULL` para la unicidad de Google (permite muchas cuentas de correo sin UID).
- **`ORDER BY` explícito** en toda consulta que devuelva listas: sin él PostgreSQL no garantiza orden (SQL Server tendía a devolver por clave primaria y la app dependía de eso sin saberlo).

### Fechas y zonas horarias con Npgsql

Desde Npgsql 6, `timestamptz` solo acepta `DateTime` con `Kind=Utc` y `timestamp` solo `Unspecified`. Por eso `FechasUtc.AUtc(...)` normaliza lo que llega de la API, y la app móvil envía la bitácora en UTC y la muestra en hora local. Para columnas `date` se usa `DateOnly`, y `TimeOnly` para `time`. El "hoy" del servidor para reglas de negocio es la fecha de Nicaragua (UTC−6 fijo, sin horario de verano): `FechasUtc.HoyNicaragua()`.

## Migraciones

Archivos SQL numerados en `backend/Scripts/migrations/`. Al arrancar, `MigradorBD`:

1. toma un **advisory lock** de sesión (`pg_advisory_lock`) para que dos instancias no migren a la vez;
2. crea `schema_migrations` si no existe;
3. ejecuta cada archivo pendiente **dentro de una transacción** (PostgreSQL admite DDL transaccional: si falla, no queda nada a medias) y registra versión + checksum SHA-256;
4. si un archivo ya aplicado cambió, **se detiene** con un mensaje claro.

Para cambiar el esquema: crea `004_descripcion.sql`. Nunca edites uno aplicado. Los saltos de línea se normalizan antes del checksum, así que Windows/Linux no generan falsos conflictos.

Las **reglas agronómicas** no son migraciones: `SembrarReglasIniciales` crea las combinaciones faltantes con `INSERT ... ON CONFLICT DO NOTHING` en cada arranque (si agregas un cultivo al catálogo, aparecen sus reglas `PENDIENTE`), y `AplicarContenidoPreliminar` solo rellena las que siguen `PENDIENTE`: **nunca pisa lo que edite un administrador** (antes lo hacía en cada reinicio).

## Seguridad y operación

- **Roles**: `postgres` (superusuario, administración) y `cosechaclima_app` (sin `SUPERUSER`, `CREATEDB` ni `CREATEROLE`, dueño de su base). Lo crea `backend/Scripts/db-init/01-roles.sh` solo la primera vez que arranca el volumen. El puerto 5432 se publica únicamente en `127.0.0.1`.
- **TLS**: dentro de la red de Docker no hay TLS. Si la base está en otro servidor, usa `SSL Mode=VerifyFull` en la cadena de conexión.
- **Contraseñas**: se aplican solo al inicializar el volumen; luego `ALTER ROLE cosechaclima_app PASSWORD '...'`.
- **Pool**: `Maximum Pool Size=20` en el ejemplo; el valor por defecto de Npgsql es 100. Cada instancia de la API tiene su propio pool: `instancias × tamaño` no debe superar `max_connections` (100 por defecto en PostgreSQL).
- **Volumen en la imagen 18**: la imagen oficial `postgres:18` guarda los datos en `/var/lib/postgresql/<versión>/` y espera el volumen en `/var/lib/postgresql`. Montarlo en `/var/lib/postgresql/data` (como en 17 y anteriores) hace que el contenedor falle al arrancar. `compose.yaml` ya lo hace bien. **Actualizar de 17 a 18 requiere `pg_dump`/`pg_restore` (o `pg_upgrade`); no basta con cambiar la etiqueta de la imagen.**
- **Respaldos**: `docker compose exec db pg_dump -U postgres -Fc cosechaclima > respaldo.dump` y `pg_restore` para restaurar. Programa uno periódico y **pruébalo restaurando**.
- **Mantenimiento**: autovacuum viene activado por defecto; para este volumen de datos no hace falta ajustarlo.

## Migrar datos desde SQL Server

> **Estado:** esta guía no se probó contra una instancia real de SQL Server (no había una disponible al hacer el cambio). Sí se verificó en PostgreSQL 16 que `\copy` y `OVERRIDING SYSTEM VALUE` aceptan ids explícitos en columnas `GENERATED ALWAYS` y que `setval(pg_get_serial_sequence(...))` ajusta la secuencia. Ensáyala primero con una copia.

Si no tienes datos que conservar, no hace falta: arranca con una base nueva y listo (las migraciones y los catálogos se crean solos).

Si sí hay usuarios y parcelas reales:

1. **Arranca la API una vez** contra PostgreSQL para que cree el esquema y los catálogos.
2. **Exporta de SQL Server** cada tabla a CSV con `bcp` o `sqlcmd` (UTF-8, cabecera aparte). Tablas a llevar, en este orden por las claves foráneas: `Usuarios`, `Parcelas`, `UmbralConfiguracion`, `DatosClimaticos`, `BitacoraCampo`, `Alertas`, `ReportesComunitarios`. Los catálogos y las reglas **no** se migran (ya existen), salvo las reglas que un admin haya editado: expórtalas y aplícalas con `UPDATE` por la clave (evento, cultivo, etapa, suelo).
3. **Carga conservando los ids** (para que las claves foráneas sigan valiendo):
   ```sql
   \copy usuarios (id, nombre, email, google_uid, password_hash, password_salt, proveedor, foto_url, fecha_registro, activo, es_admin) FROM 'usuarios.csv' WITH (FORMAT csv)
   -- ...igual con parcelas, umbrales_configuracion, etc.
   ```
4. **Ajusta cada secuencia** al máximo id cargado (si no, el próximo INSERT choca con un id existente):
   ```sql
   SELECT setval(pg_get_serial_sequence('usuarios', 'id'), (SELECT max(id) FROM usuarios));
   ```
5. **Revisa las fechas**: SQL Server guardaba `DATETIME2` sin zona (en la hora del servidor). Si el servidor estaba en UTC, cárgalas tal cual; si no, conviértelas antes. Las columnas `date` no tienen este problema.
6. **Contraseñas y Google**: los hashes PBKDF2 y los `GoogleUid` son compatibles tal cual (no dependen de la base).
7. **Sesiones**: los JWT de 24 h emitidos antes del cambio caducan solos; los usuarios tendrán que iniciar sesión una vez (no existían refresh tokens).

## Referencias

- [Documentación de Npgsql](https://www.npgsql.org/doc/basic-usage.html) y [manejo de fechas](https://www.npgsql.org/doc/types/datetime.html)
- [PostgreSQL: INSERT ... ON CONFLICT](https://www.postgresql.org/docs/current/sql-insert.html), [restricciones y claves foráneas](https://www.postgresql.org/docs/current/ddl-constraints.html), [advisory locks](https://www.postgresql.org/docs/current/explicit-locking.html#ADVISORY-LOCKS)
- [Don't Do This (wiki de PostgreSQL)](https://wiki.postgresql.org/wiki/Don%27t_Do_This)
- [Imagen oficial `postgres` en Docker](https://hub.docker.com/_/postgres)
- [OWASP Password Storage Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html) (PBKDF2-HMAC-SHA256 con 600.000 iteraciones)
