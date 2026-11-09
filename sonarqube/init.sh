#!/bin/sh
# Aprovisiona SonarQube por su Web API, sin pasos manuales en la interfaz. Lo ejecuta el contenedor
# one-shot `sonar-init` antes de que arranque Jenkins. Es idempotente: en cada `docker compose up`
# deja el mismo estado, exista o no lo creado en la ejecución anterior.
#
#   1. Espera a que SonarQube esté UP.
#   2. Cambia la contraseña por defecto admin/admin por SONAR_ADMIN_PASSWORD y fija la URL pública
#      (sonar.core.serverBaseURL), que es la que usan los enlaces "SonarQube" de cada build en Jenkins.
#   3. Crea el Quality Gate "RHM" (cobertura >= 70 %) y lo marca como gate por defecto.
#   4. Crea los proyectos analizados por los pipelines.
#   5. Registra el webhook hacia Jenkins (lo necesita waitForQualityGate).
#   6. Genera el token de análisis y lo deja en /run/sonar/token, de donde lo lee JCasC.
set -eu

SONAR_URL=${SONAR_URL:-http://sonarqube:9000}
ADMIN_PASSWORD_FILE=${SONAR_ADMIN_PASSWORD_FILE:-/run/secrets/sonar_admin_password}
[ -s "$ADMIN_PASSWORD_FILE" ] || { echo "Falta el secreto $ADMIN_PASSWORD_FILE" >&2; exit 1; }
ADMIN_PASSWORD=$(cat "$ADMIN_PASSWORD_FILE")
QUALITY_GATE=${SONAR_QUALITY_GATE:-RHM}
PROJECTS=${SONAR_PROJECTS:-"api-gateway auth-service ms-departments ms-employees ms-notifications ms-profiles ms-vacation"}
PUBLIC_URL=${SONAR_PUBLIC_URL:-http://localhost:9000}
WEBHOOK_URL=${SONAR_WEBHOOK_URL:-http://jenkins:8080/sonarqube-webhook/}
TOKEN_NAME=${SONAR_TOKEN_NAME:-jenkins-ci}
TOKEN_FILE=${SONAR_TOKEN_FILE:-/run/sonar/token}

log() { echo "[sonar-init] $*"; }

# api METODO RUTA [parametros...]: llamada autenticada como admin. Imprime el cuerpo y devuelve el
# código HTTP en la variable global STATUS.
api() {
  method=$1 path=$2
  shift 2
  out=$(curl -sS -u "admin:$ADMIN_PASSWORD" -X "$method" -w '\n%{http_code}' "$SONAR_URL$path" "$@")
  STATUS=$(printf '%s' "$out" | tail -n1)
  BODY=$(printf '%s' "$out" | sed '$d')
}

log "esperando a SonarQube en $SONAR_URL ..."
attempt=0
until curl -fsS "$SONAR_URL/api/system/status" 2>/dev/null | grep -q '"status":"UP"'; do
  attempt=$((attempt + 1))
  if [ "$attempt" -ge 90 ]; then
    log "SonarQube no respondió UP tras 90 intentos (~7 min)"
    exit 1
  fi
  sleep 5
done
log "SonarQube UP"

# --- 2. Contraseña del administrador --------------------------------------------------------------
if curl -fsS -u "admin:$ADMIN_PASSWORD" "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
  log "la contraseña de admin ya estaba cambiada"
elif curl -fsS -u admin:admin "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
  curl -fsS -u admin:admin -X POST "$SONAR_URL/api/users/change_password" \
    --data-urlencode login=admin --data-urlencode previousPassword=admin \
    --data-urlencode "password=$ADMIN_PASSWORD"
  log "contraseña por defecto de admin reemplazada"
else
  # Alguien cambió la contraseña a mano. Si el token que ya tiene Jenkins sigue siendo válido no
  # hace falta nada más; si no, no hay forma de continuar sin la contraseña correcta.
  if [ -s "$TOKEN_FILE" ] && curl -fsS -u "$(cat "$TOKEN_FILE"):" "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
    log "AVISO: SONAR_ADMIN_PASSWORD no coincide, pero el token existente es válido; se conserva"
    exit 0
  fi
  log "ERROR: ni SONAR_ADMIN_PASSWORD ni admin/admin son válidos"
  exit 1
fi

# URL pública: sin ella el scanner arma el enlace al dashboard con la URL interna de Docker
# (http://sonarqube:9000), que el navegador no resuelve.
api POST /api/settings/set --data-urlencode key=sonar.core.serverBaseURL --data-urlencode "value=$PUBLIC_URL"
[ "$STATUS" = 204 ] || [ "$STATUS" = 200 ] || { log "no se pudo fijar la URL pública: $BODY"; exit 1; }
log "URL pública de SonarQube: $PUBLIC_URL"

# --- 3. Quality Gate ------------------------------------------------------------------------------
api GET /api/qualitygates/show --get --data-urlencode "name=$QUALITY_GATE"
if [ "$STATUS" != 200 ]; then
  api POST /api/qualitygates/create --data-urlencode "name=$QUALITY_GATE"
  [ "$STATUS" = 200 ] || { log "no se pudo crear el Quality Gate: $BODY"; exit 1; }
  log "Quality Gate $QUALITY_GATE creado"
fi

# Cada condición se reconcilia: se actualiza si la métrica ya tiene condición (SonarQube agrega
# algunas por defecto al crear un gate) y se crea si no. Formato: métrica operador umbral.
# "coverage" es sobre todo el código: con solo condiciones sobre código nuevo, el primer análisis
# (sin período de referencia) nunca evaluaría la cobertura.
while read -r metric op error; do
  api GET /api/qualitygates/show --get --data-urlencode "name=$QUALITY_GATE"
  condition_id=$(printf '%s' "$BODY" | tr '{' '\n' | grep "\"metric\":\"$metric\"" \
    | sed -n 's/.*"id":"\{0,1\}\([^",]*\).*/\1/p' | head -n1)
  if [ -n "$condition_id" ]; then
    api POST /api/qualitygates/update_condition --data-urlencode "id=$condition_id" \
      --data-urlencode "metric=$metric" --data-urlencode "op=$op" --data-urlencode "error=$error"
  else
    api POST /api/qualitygates/create_condition --data-urlencode "gateName=$QUALITY_GATE" \
      --data-urlencode "metric=$metric" --data-urlencode "op=$op" --data-urlencode "error=$error"
  fi
  case $STATUS in
    200|204) log "  condición: $metric $op $error" ;;
    *) log "no se pudo configurar la condición $metric: $BODY"; exit 1 ;;
  esac
done <<'CONDITIONS'
coverage LT 70
new_coverage LT 70
new_duplicated_lines_density GT 3
new_reliability_rating GT 1
new_security_rating GT 1
new_maintainability_rating GT 1
CONDITIONS

# Las condiciones que SonarQube agregó por defecto y no están en la lista anterior se eliminan, para
# que el gate sea exactamente el documentado.
api GET /api/qualitygates/show --get --data-urlencode "name=$QUALITY_GATE"
printf '%s' "$BODY" | tr '{' '\n' | sed -n 's/^"id":"\{0,1\}\([^",]*\)"\{0,1\},"metric":"\([^"]*\)".*/\1 \2/p' |
  while read -r condition_id metric; do
    case " coverage new_coverage new_duplicated_lines_density new_reliability_rating new_security_rating new_maintainability_rating " in
      *" $metric "*) ;;
      *)
        api POST /api/qualitygates/delete_condition --data-urlencode "id=$condition_id"
        log "  condición por defecto eliminada: $metric"
        ;;
    esac
  done
api POST /api/qualitygates/set_as_default --data-urlencode "name=$QUALITY_GATE"
[ "$STATUS" = 204 ] || [ "$STATUS" = 200 ] || { log "no se pudo marcar $QUALITY_GATE por defecto: $BODY"; exit 1; }

# --- 4. Proyectos ---------------------------------------------------------------------------------
for project in $PROJECTS; do
  api POST /api/projects/create --data-urlencode "project=$project" --data-urlencode "name=$project"
  case $STATUS in
    200) log "proyecto $project creado" ;;
    400) log "proyecto $project ya existe" ;;
    *) log "no se pudo crear el proyecto $project: $BODY"; exit 1 ;;
  esac
done

# --- 5. Webhook hacia Jenkins ---------------------------------------------------------------------
api GET /api/webhooks/list
if printf '%s' "$BODY" | grep -q "\"url\":\"$WEBHOOK_URL\""; then
  log "webhook hacia $WEBHOOK_URL ya existe"
else
  api POST /api/webhooks/create --data-urlencode name=jenkins --data-urlencode "url=$WEBHOOK_URL"
  [ "$STATUS" = 200 ] || { log "no se pudo crear el webhook: $BODY"; exit 1; }
  log "webhook hacia $WEBHOOK_URL creado"
fi

# --- 6. Token de análisis para Jenkins ------------------------------------------------------------
if [ -s "$TOKEN_FILE" ] && curl -fsS -u "$(cat "$TOKEN_FILE"):" "$SONAR_URL/api/authentication/validate" | grep -q '"valid":true'; then
  log "el token existente sigue siendo válido"
  exit 0
fi
# El valor de un token solo se puede leer al crearlo: si se perdió, se revoca y se genera de nuevo.
api POST /api/user_tokens/revoke --data-urlencode login=admin --data-urlencode "name=$TOKEN_NAME"
api POST /api/user_tokens/generate --data-urlencode login=admin --data-urlencode "name=$TOKEN_NAME" \
  --data-urlencode type=GLOBAL_ANALYSIS_TOKEN
[ "$STATUS" = 200 ] || { log "no se pudo generar el token: $BODY"; exit 1; }
token=$(printf '%s' "$BODY" | sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
[ -n "$token" ] || { log "respuesta inesperada al generar el token"; exit 1; }

mkdir -p "$(dirname "$TOKEN_FILE")"
umask 077
printf '%s' "$token" > "$TOKEN_FILE.tmp"
# Jenkins (uid 1000) debe poder leerlo; nadie más lo necesita.
chown 1000:1000 "$TOKEN_FILE.tmp" 2>/dev/null || chmod 644 "$TOKEN_FILE.tmp"
mv "$TOKEN_FILE.tmp" "$TOKEN_FILE"
log "token de análisis generado en $TOKEN_FILE"
