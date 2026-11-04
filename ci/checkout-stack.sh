#!/bin/sh
# Clona, como hermanos de este repositorio, todo lo que el docker-compose.yml construye más la suite
# BDD. Lo usa la etapa "E2E Tests" de los Jenkinsfile:
#
#   .e2e/
#   ├── rhm-database-infrastructure/   ← este repositorio (lo clona el Jenkinsfile)
#   ├── ms-employees/ ms-departments/ ms-notifications/ ms-profiles/ ms-vacation/
#   ├── auth-service/ api-gateway/
#   └── e2e-tests/
#
# Cada repositorio se toma de la rama RHM_GIT_BRANCH si existe, y si no de su rama por defecto.
# Clones superficiales (--depth 1): solo hace falta el último estado, no la historia.
set -eu

: "${RHM_GIT_BASE_URL:?Defina RHM_GIT_BASE_URL, p. ej. https://github.com/Microservicios-RHM}"
BRANCH=${RHM_GIT_BRANCH:-main}
DEST=$(cd "$(dirname "$0")/../.." && pwd)

REPOS="ms-employees ms-departments ms-notifications ms-profiles ms-vacation auth-service api-gateway e2e-tests"

for repo in $REPOS; do
  url="$RHM_GIT_BASE_URL/$repo.git"
  rm -rf "${DEST:?}/$repo"
  if git ls-remote --exit-code --heads "$url" "$BRANCH" >/dev/null 2>&1; then
    git clone --quiet --depth 1 --branch "$BRANCH" "$url" "$DEST/$repo"
  else
    git clone --quiet --depth 1 "$url" "$DEST/$repo"
  fi
  printf '  %-18s %s @ %s\n' "$repo" \
    "$(git -C "$DEST/$repo" rev-parse --abbrev-ref HEAD)" "$(git -C "$DEST/$repo" rev-parse --short HEAD)"
done
