#!/usr/bin/env sh
set -eu

: "${COMPOSE_PROJECT_NAME:?COMPOSE_PROJECT_NAME is required}"
volume="${COMPOSE_PROJECT_NAME}-secret-files"

docker volume create "$volume" >/dev/null
docker run --rm -v "$volume:/run/secrets" alpine:3.21 sh -ec '
  umask 077
  for name in jwt_secret cache_admin_token employees_db_password departments_db_password departments_db_root_password notifications_db_password profiles_db_password vacations_db_password auth_db_password; do
    printf "e2e-%s" "$name" > "/run/secrets/$name"
  done
  printf "rhmUQ" > /run/secrets/broker_password
  printf "rhmUQ" > /run/secrets/admin_password
  printf "amqp://admin:rhmUQ@message-broker:5672" > /run/secrets/broker_url
'

printf 'Provisioned ephemeral secret volume %s\n' "$volume"
