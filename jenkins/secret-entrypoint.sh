#!/bin/sh
set -eu

read_secret() {
  variable=$1
  file=$2
  [ -s "$file" ] || { echo "Missing required secret: $file" >&2; exit 1; }
  value=$(cat "$file")
  export "$variable=$value"
}

read_secret JENKINS_ADMIN_PASSWORD /run/secrets/jenkins_admin_password
read_secret ADMIN_PASSWORD /run/secrets/admin_password

exec /usr/bin/tini -- /usr/local/bin/jenkins.sh "$@"
