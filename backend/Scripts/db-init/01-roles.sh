#!/bin/bash
# Se ejecuta UNA sola vez, cuando el volumen de datos esta vacio (docker-entrypoint-initdb.d).
# Crea un rol propio para la aplicacion: NO es superusuario y solo es dueño de su base.
# El usuario "postgres" (superusuario) queda reservado para administracion.
set -euo pipefail

: "${APP_DB_PASSWORD:?Falta APP_DB_PASSWORD}"
: "${APP_DB_NAME:=cosechaclima}"
: "${APP_DB_USER:=cosechaclima_app}"

psql -v ON_ERROR_STOP=1 \
     -v app_user="$APP_DB_USER" -v app_pw="$APP_DB_PASSWORD" -v app_db="$APP_DB_NAME" \
     --username "$POSTGRES_USER" --dbname postgres <<'SQL'
CREATE ROLE :"app_user" LOGIN PASSWORD :'app_pw' NOSUPERUSER NOCREATEDB NOCREATEROLE;
CREATE DATABASE :"app_db" OWNER :"app_user" ENCODING 'UTF8';
REVOKE ALL ON DATABASE :"app_db" FROM PUBLIC;
SQL
