#!/usr/bin/env sh
set -eu

secrets_dir="${SECRETS_DIR:-secrets}"
umask 077
mkdir -p "$secrets_dir"

generate_secret() {
  file="$1"
  if [ ! -s "$secrets_dir/$file" ]; then
    openssl rand -base64 48 | tr -d '\n' > "$secrets_dir/$file"
    printf 'Created %s\n' "$secrets_dir/$file"
  fi
}

write_known_secret() {
  file="$1"
  value="$2"
  printf '%s' "$value" > "$secrets_dir/$file"
  printf 'Configured %s\n' "$secrets_dir/$file"
}

for name in \
  jwt_secret cache_admin_token \
  employees_db_password departments_db_password departments_db_root_password \
  notifications_db_password profiles_db_password vacations_db_password auth_db_password
do
  generate_secret "$name"
done

# Credenciales de acceso local acordadas para interfaces y administrador semilla. Las bases de
# datos conservan secretos aleatorios propios; nunca reutilizan esta clave.
write_known_secret broker_password 'rhmUQ'
write_known_secret admin_password 'rhmUQ'
write_known_secret jenkins_admin_password 'rhmUQ'
write_known_secret sonar_admin_password 'rhmUQ'
write_known_secret grafana_admin_password 'rhmUQ'
write_known_secret broker_url 'amqp://admin:rhmUQ@message-broker:5672'

printf 'Secrets are ready in %s. Keep this directory out of Git.\n' "$secrets_dir"
