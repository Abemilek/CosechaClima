-- Refresh tokens con rotacion y deteccion de reutilizacion.
-- Solo se guarda el SHA-256 del token (el token en claro nunca toca la base).
-- familia_id agrupa la cadena de rotaciones de un mismo inicio de sesion;
-- padre_id enlaza cada token con el que lo origino.

CREATE TABLE refresh_tokens (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    usuario_id      integer NOT NULL REFERENCES usuarios (id) ON DELETE CASCADE,
    familia_id      uuid NOT NULL,
    familia_inicio  timestamptz NOT NULL,
    padre_id        bigint NULL REFERENCES refresh_tokens (id) ON DELETE SET NULL,
    token_hash      bytea NOT NULL UNIQUE CHECK (octet_length(token_hash) = 32),
    cliente         text NOT NULL CHECK (cliente IN ('movil', 'web')),
    creado_en       timestamptz NOT NULL DEFAULT now(),
    expira_en       timestamptz NOT NULL,
    usado_en        timestamptz NULL,
    revocado_en     timestamptz NULL
);

CREATE INDEX ix_refresh_usuario ON refresh_tokens (usuario_id);
CREATE INDEX ix_refresh_familia ON refresh_tokens (familia_id);
CREATE INDEX ix_refresh_padre ON refresh_tokens (padre_id) WHERE padre_id IS NOT NULL;
CREATE INDEX ix_refresh_expira ON refresh_tokens (expira_en);
