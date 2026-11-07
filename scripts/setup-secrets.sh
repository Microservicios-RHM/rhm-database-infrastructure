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

for name in \
  broker_password jwt_secret cache_admin_token admin_password \
  employees_db_password departments_db_password departments_db_root_password \
  notifications_db_password profiles_db_password vacations_db_password auth_db_password \
  jenkins_admin_password sonar_admin_password sonar_db_password grafana_admin_password
do
  generate_secret "$name"
done

printf 'Secrets are ready in %s. Keep this directory out of Git.\n' "$secrets_dir"
