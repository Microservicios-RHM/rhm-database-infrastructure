#!/usr/bin/env sh
set -eu

export RABBITMQ_DEFAULT_PASS="$(cat "${BROKER_PASSWORD_FILE:?BROKER_PASSWORD_FILE es obligatorio}")"
exec rabbitmq-server
