#!/usr/bin/env sh
set -eu

: "${COMPOSE_PROJECT_NAME:?COMPOSE_PROJECT_NAME is required}"
volume="${COMPOSE_PROJECT_NAME}-secret-files"

docker volume create "$volume" >/dev/null
docker run --rm -v "$volume:/run/secrets" alpine:3.21 sh -ec '
  # Docker Compose secrets are mounted as root:root 0444. Reproduce those
  # permissions in the ephemeral volume so services running as a non-root uid
  # (for example perfiles-service) can read them too.
  umask 022
  for name in jwt_secret cache_admin_token employees_db_password departments_db_password departments_db_root_password notifications_db_password profiles_db_password vacations_db_password auth_db_password; do
    printf "e2e-%s" "$name" > "/run/secrets/$name"
  done
  # auth-service exige un secreto JWT de al menos 16 caracteres.
  printf "e2e-jwt-secret-for-contract-tests" > /run/secrets/jwt_secret
  printf "rhmUQ" > /run/secrets/broker_password
  printf "rhmUQ" > /run/secrets/admin_password
  printf "amqp://admin:rhmUQ@message-broker:5672" > /run/secrets/broker_url
  chmod 0444 /run/secrets/*
'

printf 'Provisioned ephemeral secret volume %s\n' "$volume"
