-- CosechaClima: esquema inicial para PostgreSQL (migrado desde SQL Server).
-- Convenciones (wiki.postgresql.org/wiki/Don't_Do_This y docs oficiales):
--   * identificadores en snake_case, sin comillas
--   * claves con GENERATED ALWAYS AS IDENTITY (no serial)
--   * text + CHECK en vez de varchar(n); timestamptz para instantes; date/time para valores locales
--   * PostgreSQL NO crea indices en las FK: se declaran a mano
-- Este archivo es inmutable: el migrador guarda su checksum. Los cambios van en archivos nuevos (002_, 003_...).

CREATE TABLE tipos_suelo (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      text NOT NULL UNIQUE CHECK (char_length(nombre) BETWEEN 1 AND 50),
    descripcion text NULL CHECK (char_length(descripcion) <= 200)
);

CREATE TABLE cultivos (
    id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre            text NOT NULL UNIQUE CHECK (char_length(nombre) BETWEEN 1 AND 50),
    nombre_cientifico text NULL CHECK (char_length(nombre_cientifico) <= 100)
);

CREATE TABLE etapas_fenologicas (
    id                 integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre             text NOT NULL UNIQUE CHECK (char_length(nombre) BETWEEN 1 AND 50),
    descripcion        text NULL CHECK (char_length(descripcion) <= 100),
    dias_desde_siembra integer NULL CHECK (dias_desde_siembra >= 0)
);

CREATE TABLE eventos_climaticos (
    id          integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre      text NOT NULL UNIQUE CHECK (char_length(nombre) BETWEEN 1 AND 50),
    descripcion text NULL CHECK (char_length(descripcion) <= 200)
);

CREATE TABLE usuarios (
    id             integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         text NOT NULL CHECK (char_length(nombre) BETWEEN 1 AND 100),
    email          text NOT NULL UNIQUE CHECK (char_length(email) <= 256 AND email = lower(email)),
    google_uid     text NULL CHECK (char_length(google_uid) <= 128),
    password_hash  text NULL CHECK (char_length(password_hash) <= 200),
    password_salt  text NULL CHECK (char_length(password_salt) <= 100),
    proveedor      smallint NOT NULL DEFAULT 0 CHECK (proveedor IN (0, 1)),   -- 0 = email, 1 = google
    foto_url       text NULL CHECK (char_length(foto_url) <= 500),
    fecha_registro timestamptz NOT NULL DEFAULT now(),
    activo         boolean NOT NULL DEFAULT true,
    es_admin       boolean NOT NULL DEFAULT false,
    CONSTRAINT ck_usuarios_credenciales CHECK (
        (proveedor = 0 AND password_hash IS NOT NULL AND password_salt IS NOT NULL)
        OR
        (proveedor = 1 AND google_uid IS NOT NULL)
    )
);

CREATE UNIQUE INDEX uq_usuarios_google_uid ON usuarios (google_uid) WHERE google_uid IS NOT NULL;

CREATE TABLE parcelas (
    id                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id           integer NOT NULL REFERENCES usuarios (id),
    cultivo_id           integer NOT NULL REFERENCES cultivos (id),
    etapa_fenologica_id  integer NULL REFERENCES etapas_fenologicas (id),
    tipo_suelo_id        integer NOT NULL REFERENCES tipos_suelo (id),
    fecha_siembra        date NOT NULL,
    area_mzs             numeric(7,2) NOT NULL CHECK (area_mzs > 0),
    latitud              numeric(9,6) NULL CHECK (latitud BETWEEN -90 AND 90),
    longitud             numeric(9,6) NULL CHECK (longitud BETWEEN -180 AND 180),
    municipio            text NULL CHECK (char_length(municipio) <= 100),
    comunidad            text NULL CHECK (char_length(comunidad) <= 100),
    fecha_registro       timestamptz NOT NULL DEFAULT now(),
    activa               boolean NOT NULL DEFAULT true
);

-- consulta principal: "mis parcelas activas"
CREATE INDEX ix_parcelas_usuario_activas ON parcelas (usuario_id) WHERE activa;

CREATE TABLE umbrales_configuracion (
    id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id        integer NOT NULL UNIQUE REFERENCES usuarios (id),
    lluvia_intensa_mm integer NOT NULL DEFAULT 100 CHECK (lluvia_intensa_mm BETWEEN 0 AND 1000),
    viento_fuerte_kmh integer NOT NULL DEFAULT 40  CHECK (viento_fuerte_kmh BETWEEN 0 AND 300),
    canicula_dias     integer NOT NULL DEFAULT 7   CHECK (canicula_dias BETWEEN 1 AND 60),
    variedad_cultivo  text NOT NULL DEFAULT 'Criollo' CHECK (char_length(variedad_cultivo) <= 50),
    tiene_riego       boolean NOT NULL DEFAULT false,
    horario_sms       time NOT NULL DEFAULT '06:00'
);

CREATE TABLE datos_climaticos (
    id                integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    parcela_id        integer NOT NULL REFERENCES parcelas (id),
    fecha             date NOT NULL,
    temperatura_media numeric(5,1) NULL,
    temperatura_max   numeric(5,1) NULL,
    temperatura_min   numeric(5,1) NULL,
    precipitacion     numeric(6,2) NULL,
    humedad_relativa  numeric(5,1) NULL,
    viento_velocidad  numeric(5,1) NULL,
    radiacion_solar   numeric(7,2) NULL,
    fuente_clima      text NOT NULL DEFAULT 'OPEN_METEO' CHECK (char_length(fuente_clima) <= 50),
    fecha_descarga    timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uk_datos_parcela_fecha UNIQUE (parcela_id, fecha)   -- su indice cubre la FK parcela_id
);

CREATE TABLE bitacora_campo (
    id                    integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id            integer NOT NULL REFERENCES usuarios (id),
    parcela_id            integer NOT NULL REFERENCES parcelas (id),
    fecha                 timestamptz NOT NULL,
    evento_climatico_id   integer NOT NULL REFERENCES eventos_climaticos (id),
    nivel_riesgo          text NOT NULL CHECK (nivel_riesgo IN ('Alto', 'Medio', 'Bajo', 'PENDIENTE')),
    accion1_texto         text NOT NULL CHECK (char_length(accion1_texto) <= 500),
    accion2_texto         text NOT NULL CHECK (char_length(accion2_texto) <= 500),
    accion3_texto         text NOT NULL CHECK (char_length(accion3_texto) <= 500),
    accion1_completada    boolean NOT NULL DEFAULT false,
    accion2_completada    boolean NOT NULL DEFAULT false,
    accion3_completada    boolean NOT NULL DEFAULT false,
    notas                 text NULL CHECK (char_length(notas) <= 2000),
    sincronizado          boolean NOT NULL DEFAULT false,
    fecha_sincronizacion  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_bitacora_usuario_fecha ON bitacora_campo (usuario_id, fecha DESC);
CREATE INDEX ix_bitacora_parcela ON bitacora_campo (parcela_id);

CREATE TABLE reglas_decision (
    id                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    evento_climatico_id  integer NOT NULL REFERENCES eventos_climaticos (id),
    cultivo_id           integer NOT NULL REFERENCES cultivos (id),
    etapa_fenologica_id  integer NOT NULL REFERENCES etapas_fenologicas (id),
    tipo_suelo_id        integer NOT NULL REFERENCES tipos_suelo (id),
    nivel_riesgo         text NOT NULL CHECK (nivel_riesgo IN ('Alto', 'Medio', 'Bajo', 'PENDIENTE')),
    accion1              text NOT NULL CHECK (char_length(accion1) <= 500),
    accion2              text NOT NULL CHECK (char_length(accion2) <= 500),
    accion3              text NOT NULL CHECK (char_length(accion3) <= 500),
    descripcion_alerta   text NOT NULL CHECK (char_length(descripcion_alerta) <= 500),
    activa               boolean NOT NULL DEFAULT true,
    CONSTRAINT uk_reglas_decision_clave UNIQUE (evento_climatico_id, cultivo_id, etapa_fenologica_id, tipo_suelo_id)
);

CREATE TABLE reportes_comunitarios (
    id            integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id    integer NOT NULL REFERENCES usuarios (id),
    municipio     text NOT NULL CHECK (char_length(municipio) <= 100),
    sintomas      text NOT NULL CHECK (char_length(sintomas) <= 500),
    fecha_reporte timestamptz NOT NULL DEFAULT now(),
    latitud       numeric(10,6) NOT NULL,
    longitud      numeric(10,6) NOT NULL
);

CREATE INDEX ix_reportes_usuario ON reportes_comunitarios (usuario_id);

CREATE TABLE alertas (
    id                   integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id           integer NOT NULL REFERENCES usuarios (id),
    parcela_id           integer NOT NULL REFERENCES parcelas (id),
    fecha                date NOT NULL,
    evento_climatico_id  integer NOT NULL REFERENCES eventos_climaticos (id),
    nivel_riesgo         text NOT NULL CHECK (nivel_riesgo IN ('Alto', 'Medio', 'Bajo', 'PENDIENTE')),
    accion1              text NOT NULL,
    accion2              text NOT NULL,
    accion3              text NOT NULL,
    descripcion_alerta   text NOT NULL,
    fecha_generacion     timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT uk_alerta_parcela_fecha UNIQUE (parcela_id, fecha)
);

CREATE INDEX ix_alertas_usuario ON alertas (usuario_id);
CREATE INDEX ix_alertas_generacion ON alertas (fecha_generacion DESC);
