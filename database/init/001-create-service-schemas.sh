#!/bin/sh
set -eu

psql \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  --set=db_name="$POSTGRES_DB" \
  --set=employees_user="$EMPLOYEES_DB_USER" \
  --set=employees_password="$EMPLOYEES_DB_PASSWORD" <<'SQL'
SELECT format('CREATE ROLE %I LOGIN PASSWORD %L', :'employees_user', :'employees_password')
WHERE NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'employees_user')
\gexec

CREATE SCHEMA IF NOT EXISTS employees AUTHORIZATION :"employees_user";

REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT CONNECT ON DATABASE :"db_name" TO :"employees_user";
GRANT USAGE, CREATE ON SCHEMA employees TO :"employees_user";

ALTER ROLE :"employees_user" IN DATABASE :"db_name" SET search_path TO employees;
SQL
