#!/bin/sh
# Arranca como root solo para resolver el permiso sobre /var/run/docker.sock y luego ejecuta Jenkins
# como el usuario jenkins (uid 1000), igual que la imagen oficial.
set -eu

SOCKET=/var/run/docker.sock

if [ -S "$SOCKET" ]; then
  gid=$(stat -c %g "$SOCKET")
  group=$(getent group "$gid" | cut -d: -f1 || true)
  if [ -z "$group" ]; then
    group=docker-host
    groupadd --gid "$gid" "$group"
  fi
  usermod --append --groups "$group" jenkins
  # Los Jenkinsfile lo pasan a los agentes Docker (--group-add) que también usan el socket,
  # por ejemplo para Testcontainers en las pruebas de integración.
  export DOCKER_GID="$gid"
else
  echo "AVISO: $SOCKET no está montado; los pipelines no podrán construir imágenes." >&2
fi

export HOME=/var/jenkins_home
exec setpriv --reuid=jenkins --regid=jenkins --init-groups /usr/local/bin/jenkins.sh "$@"
