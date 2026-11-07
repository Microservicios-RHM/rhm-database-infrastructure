# Criterios de evaluación pendientes — Entrega final

> Comparación entre `proyectoFinal.pdf` y lo implementado en `Microservicios/` (estado al 2026-10-29).
> Leyenda: ✅ cumplido · ⚠️ parcial · ❌ pendiente

## Resumen por criterio

| # | Criterio | Peso | Estado | Lo más crítico que falta |
|---|----------|------|--------|--------------------------|
| 1 | Funcionalidad | 35 % | ⚠️ Avanzado | Endpoint opcional `/empleados/{id}/completo`, estado `EN_VACACIONES` en empleados, verificar E2E completos |
| 2 | Calidad Técnica | 25 % | ⚠️ Parcial | **Tests en 3 servicios (gateway, auth, departamentos)**, health checks con dependencias y 503, cobertura ≥70 % en todos |
| 3 | Observabilidad | 15 % | ❌ **No iniciado** | Loki/Promtail, Prometheus, Grafana, alertas, OpenTelemetry + Zipkin/Jaeger |
| 4 | Seguridad y Configuración | 10 % | ⚠️ Parcial | Valores por defecto con secretos en `docker-compose.yml`, Docker Secrets, `setup-secrets.sh`, (bonus) Keycloak + JWKS |
| 5 | Escalabilidad y Resiliencia | 10 % | ⚠️ Parcial | Réplicas + load balancer; quitar `container_name` |
| 6 | DevOps | 5 % | ⚠️ Parcial | Jenkinsfile solo en 2 de 7 servicios |
| 7 | Documentación | 5 % | ⚠️ Parcial | README raíz, `docs/arquitectura.md`, guías de terceros, estructura de entrega |

---

## 1. Funcionalidad (35 %)

### Ya cumplido
- ✅ 6 microservicios de negocio + API Gateway, en 6 lenguajes (Node/TS, PHP, Python, Go, Ruby): se cumple la restricción de ≥4.
- ✅ Onboarding: `empleado.creado` → auth crea la cuenta inactiva con token de activación → `usuario.creado` → notificaciones envía el correo (sin contraseña).
- ✅ Auth: login, `reset-password`, `recover-password`, `change-password`, BCrypt (`bcryptjs`), y no hay `/register`.
- ✅ Vacaciones: scheduler que publica `vacaciones.iniciadas`/`finalizadas`; validaciones de fechas pasadas, solapamiento y empleado existente.
- ✅ Ciclo de vida de la cuenta: `SUSPENDIDA_TEMPORAL` vs `DESACTIVADA_PERMANENTE`, `cuenta.activada`/`cuenta.desactivada`.
- ✅ Offboarding: el retiro es una transición a `RETIRADO`, hay consulta de auditoría con `?estado=RETIRADO&desde=&hasta=` y el perfil se archiva.
- ✅ Deduplicación por `id` de envelope en los consumidores (auth, notificaciones, perfiles, vacaciones).
- ✅ El gateway enruta `/auth`, `/empleados`, `/departamentos`, `/perfiles`, `/vacaciones`, con RBAC y control de propiedad en `PUT /perfiles/{id}` (403).

### Pendiente
- [ ] **Estado `EN_VACACIONES` en empleados-service**: el enum existe, pero ms-employees no consume `vacaciones.iniciadas`/`finalizadas`, así que el empleado nunca cambia de estado. Hay que decidir si se implementa el consumo (y añadirlo al catálogo) o justificar en la documentación por qué no se usa.
- [ ] **(Opcional, da puntaje adicional) `GET /empleados/{id}/completo`** en el gateway: componer empleado + perfil y manejar el fallo parcial (por ejemplo, devolver el empleado con `perfil: null` y un aviso si perfiles no responde).
- [ ] **Plantillas de notificación configurables**: hoy están fijas en código (`ms-notifications/app/infrastructure/email/notification_template.py`). Conviene sacarlas a archivos (Jinja2) o a la base de datos, con la ruta configurable por variable de entorno.
- [ ] Correr la suite `e2e-tests` completa (onboarding, perfil, vacaciones, offboarding, seguridad) contra el stack final y guardar la evidencia.
- [ ] Añadir un escenario E2E de **gestión de perfil** (actualizar el propio y recibir 403 sobre el ajeno). Hoy no hay ninguna `.feature` de perfiles.
- [ ] Revisar `docs/event-catalog.md`: se titula "Retos 4 y 5" y debe quedar como `docs/eventos.md` final, alineado con lo implementado.

---

## 2. Calidad Técnica (25 %)

### Pruebas automatizadas y cobertura ≥ 70 %
| Servicio | Lenguaje | Archivos de test | Umbral 70 % aplicado |
|----------|----------|------------------|----------------------|
| api-gateway | Node/TS | ❌ 0 | ❌ |
| auth-service | Node/TS | ❌ 0 | ❌ |
| ms-departments | PHP | ❌ 0 | ❌ |
| ms-employees | Node/TS | ✅ 8 | ✅ `test:ci --test-coverage-lines=70` |
| ms-notifications | Python | ✅ 13 | ⚠️ falta `--cov-fail-under=70` |
| ms-profiles | Go | ✅ 7 | ⚠️ falta verificar el umbral |
| ms-vacation | Ruby | ✅ 16 | ✅ `minimum_coverage 70` |

- [ ] **Escribir pruebas unitarias y de integración (camino feliz de todas las operaciones)** para api-gateway, auth-service y ms-departments (PHPUnit).
- [ ] Hacer que la cobertura <70 % falle en notificaciones (pytest-cov) y en perfiles (`go test -cover` + script de umbral).
- [ ] Tener en cuenta las pruebas nuevas que exijan las demás secciones (health checks, tracing y métricas).

### Health checks (formato exigido)
Hoy **todos** responden `200 {status: "UP"}` fijo, sin revisar dependencias. Falta:
- [ ] Revisar de verdad la base de datos y el broker en cada servicio.
- [ ] Usar el formato `{"status","service","checks":{"database","messageBroker"}}`.
- [ ] Devolver **HTTP 503** cuando el estado sea DOWN.
- [ ] En el gateway, que el health considere el de los servicios que hay detrás (o al menos documentar el criterio).

### OpenAPI / Swagger
- ✅ Hay especificación y Swagger UI en empleados, departamentos, auth, perfiles, vacaciones y notificaciones (FastAPI).
- [ ] Publicar **Swagger UI agregado en el gateway** (`http://localhost:8080/swagger`, como pide el README de referencia).
- [ ] Dejar un `openapi.yaml` exportado en la raíz de cada microservicio (lo pide la estructura de entrega).
- [ ] Revisar que cada spec documente todos los modelos y códigos de respuesta (400/401/403/404/409/503).

### Dockerfiles
- ✅ Multi-stage y usuario no root en casi todos.
- [ ] `ms-notifications/Dockerfile` es de una sola etapa: pasarlo a multi-stage (builder con wheels → runtime slim).
- [ ] `ms-departments`: correr como usuario no root.
- [ ] Revisar que el `.dockerignore` de ms-notifications excluya `.venv/`, `.pytest_cache/` y `__pycache__/`.

---

## 3. Observabilidad (15 %) — ❌ todo pendiente

No hay ningún rastro de OpenTelemetry, Prometheus, Loki ni Zipkin en el código ni en el compose.

### Logs centralizados
- [ ] Añadir **Loki + Promtail** (o ELK, justificándolo en el README) al compose.
- [ ] Logs JSON con `timestamp, level, service, message, context, traceId` en **todos** los servicios:
  - El gateway usa `console.log`: hay que migrarlo a pino.
  - Revisar el formato JSON en departamentos (PHP, usar Monolog), perfiles (slog), vacaciones y notificaciones.
- [ ] Configurar Promtail para leer los logs de los contenedores (docker_sd o el log driver).

### Monitoreo
- [ ] Añadir **Prometheus + Grafana** al compose.
- [ ] Exponer `/metrics` en cada servicio (prom-client, prometheus_client, client_golang, prometheus-client-ruby, PHP prometheus_client).
- [ ] Métricas de negocio: `empleados_creados_total`, `notificaciones_enviadas_total`, `errores_total`, eventos consumidos/duplicados y estado del circuit breaker.
- [ ] Dashboards de Grafana provisionados como código (`observabilidad/dashboards/*.json`), con datasources para Prometheus, Loki y Zipkin/Jaeger.

### Alertas hacia un canal externo
- [ ] Reglas de alerta (servicio caído, tasa de 5xx, circuit breaker abierto, cola con mensajes acumulados).
- [ ] Contact point externo (Slack, Discord, Telegram o email vía MailHog) configurado con Grafana Alerting o Alertmanager, y una prueba demostrable.

### Trazabilidad distribuida
- [ ] Instrumentar con **OpenTelemetry** los 7 servicios (HTTP entrante/saliente, pg, mysql, amqp).
- [ ] Propagar W3C `traceparent` **también por RabbitMQ** (en los headers del mensaje al publicar y extraerlo al consumir). Sin esto, la cascada del onboarding se corta en el broker.
- [ ] Desplegar **Zipkin (:9411) o Jaeger (:16686)** y un OTel Collector si hace falta.
- [ ] Demostrar la traza completa de onboarding: Gateway → empleados → departamentos → broker → auth → notificaciones / perfiles / vacaciones.
- [ ] Incluir el `traceId` en los logs para correlacionar log ↔ traza (y enlazarlo desde Loki en Grafana).

---

## 4. Seguridad y Configuración (10 %)

### Ya cumplido
- ✅ `.env` excluido por `.gitignore` y `.env.example` versionado (en `rhm-database-infrastructure`).
- ✅ Contraseñas con BCrypt; correos solo con token, nunca con contraseña.
- ✅ RBAC (ADMIN/USER) y autorización por propiedad del perfil en el gateway; el token de reset no sirve como token de acceso.

### Pendiente
- [ ] **Quitar los valores por defecto con secretos de `docker-compose.yml`**: hoy hay `${BROKER_PASSWORD:-admin}`, `${JWT_SECRET:-change_this_jwt_secret}`, `${SONAR_ADMIN_PASSWORD:-Rhm-Sonar-2026}`, `${DB_*_PASSWORD:-..._local_password}`, `SONAR_DB_PASSWORD:-sonar`, etc. Usar `${VAR:?falta VAR}` o, mejor, secretos.
- [ ] **Docker Compose Secrets** (o Vault) para contraseñas de BD, broker, JWT, admin semilla, Jenkins y Sonar. Leerlos desde `/run/secrets/*` (variables `*_FILE`) en cada servicio.
- [ ] `scripts/setup-secrets.sh`, que genere los archivos de `secrets/` con valores aleatorios (`openssl rand`), y `secrets.example/` con plantillas.
- [ ] Que `.gitignore` en la raíz excluya `.env` **y `secrets/`**.
- [ ] Revisar el historial de Git de los 9 repos para confirmar que nunca se commiteó un secreto (`gitleaks detect` o `git log -p | grep`). Las credenciales de la colección Postman también.
- [ ] Revisar que el `BROKER_URL` con contraseña no termine en logs.
- [ ] **(Puntaje adicional) Opción (b)**: Keycloak/Authentik como IdP OAuth2/OIDC, el gateway validando con **JWKS** y auth-service reducido a sincronizar el ciclo de vida de la cuenta. Hoy se usa la opción (a), HS256 con secreto compartido.

---

## 5. Escalabilidad y Resiliencia (10 %)

### Ya cumplido
- ✅ Circuit breaker (opossum) con fallback (caché `node-cache`), timeout y reintentos con backoff en empleados → departamentos.
- ✅ Reconexión al broker en auth-service.

### Pendiente
- [ ] **Quitar `container_name`** de los servicios de negocio, porque impide `docker compose up --scale` / `deploy.replicas`.
- [ ] Definir **réplicas** (al menos 2) de los servicios stateless (empleados, departamentos, perfiles, auth, gateway).
- [ ] **Load balancer** con health checks entre instancias: Traefik o Nginx delante del gateway y/o de los servicios. Otra opción es el DNS round-robin de Docker con health checks activos, documentándolo.
- [ ] **Scheduler de vacaciones con varias réplicas**: evitar que se publique dos veces (lock con `SELECT … FOR UPDATE SKIP LOCKED` o advisory lock), o dejar una sola instancia y justificarlo.
- [ ] Revisar que todos los servicios sean stateless. La caché en memoria de departamentos es por instancia: aceptable, pero hay que documentarlo.
- [ ] Timeouts en el proxy del gateway (`proxyTimeout`/`timeout`) y, si aplica, reintentos.
- [ ] **Demo documentada**: detener una instancia (`docker stop`) y mostrar que el sistema sigue respondiendo; tumbar departamentos y mostrar que el circuit breaker se abre y se usa el fallback.

---

## 6. DevOps (5 %)

### Ya cumplido
- ✅ Jenkins (JCasC, sin wizard), SonarQube con Quality Gate de cobertura ≥70 % y registry local en el compose.
- ✅ Pipelines completos (Checkout → Build → Test → SonarQube → Quality Gate → Package → Publish → E2E) en **ms-employees** y **ms-vacation**.

### Pendiente
- [ ] **Jenkinsfile para api-gateway, auth-service, ms-departments, ms-notifications y ms-profiles**, y registrar los 7 jobs en `jenkins/casc.yaml` (hoy solo hay 2).
- [ ] Proyectos SonarQube para los 7 servicios en `sonarqube/init.sh` (más el `sonar-project.properties` de cada uno).
- [ ] Etapa de **linting y análisis de seguridad** en cada pipeline (eslint, ruff/bandit, golangci-lint/gosec, rubocop, phpstan; `npm audit`/`trivy` para las imágenes).
- [ ] Trigger por **webhook** (o polling SCM documentado) en lugar de solo ejecuciones manuales.
- [ ] **Puerto de Jenkins**: está en `9090`, que choca con Prometheus. Moverlo a `8090`, como en el diagrama.
- [ ] **Commitear y pushear** los cambios locales sin versionar:
  - `ms-employees`: `Jenkinsfile`, `sonar-project.properties`, `tsconfig.sonar.json`, `.gitignore`, `.dockerignore`.
  - `ms-vacation`: `Jenkinsfile`, `README.md`, `coverage_helper.rb`, etc.
  - `rhm-database-infrastructure`: `jenkins/`, `sonarqube/`, `ci/`, `docker-compose.yml`, colección Postman.
  - `e2e-tests`: no tiene remoto/merge revisado.

---

## 7. Documentación y entregable (5 % + restricciones obligatorias)

### Estructura y despliegue unificado (restricción obligatoria 3 y 5)
- [ ] **`docker-compose.yml` en la raíz del proyecto**: hoy está en `rhm-database-infrastructure/` y usa `../ms-*` como contexto. Hay que armar el directorio de entrega `proyecto-final-microservicios/`, por ejemplo:
  ```
  proyecto-final-microservicios/
  ├── README.md  docker-compose.yml  .env.example  .gitignore  secrets.example/
  ├── microservicios/{gestion-empleados, gestion-departamentos, autenticacion, gestion-perfiles,
  │                   gestion-vacaciones, notificaciones, api-gateway}/  (Dockerfile, Jenkinsfile, src, tests, openapi.yaml)
  ├── e2e-tests/
  ├── observabilidad/{logs, monitoreo, trazas, dashboards}/
  ├── docs/{arquitectura.md, eventos.md, guias/}
  └── scripts/{setup-secrets.sh, init-db.sql, seed-data.sql}
  ```
- [ ] Revisar que `docker compose up --build` desde la raíz compile, empaquete y despliegue **todo** (servicios + observabilidad + Jenkins/Sonar/registry) sin pasos manuales.
- [ ] Separar las redes por capa (frontend, backend, messaging, data, observability, cicd). Hoy hay una sola: `microservices-network`.
- [ ] `scripts/seed-data.sql` con departamentos y empleados de prueba; `init-db.sql` unificado o referenciado.
- [ ] Generar el comprimido final (`.zip`/`.tar.gz`) sin `node_modules`, `.venv`, `.pytest_cache`, `.env` ni `secrets/`.

### README.md raíz (contenido mínimo exigido)
- [ ] 1. Descripción y arquitectura general.
- [ ] 2. Requisitos previos y versiones mínimas (Docker, Compose).
- [ ] 3. Ejecución: `cp .env.example .env` → `bash scripts/setup-secrets.sh` → `docker compose up --build`, con las URLs (gateway, swagger, Jenkins, Grafana, Prometheus, Zipkin/Jaeger, RabbitMQ, MailHog, Sonar).
- [ ] 4. Tabla microservicio ↔ lenguaje ↔ BD, broker y herramientas de observabilidad.
- [ ] 5. Endpoints del gateway con ejemplos `curl`.
- [ ] 6. Configuración de secretos: qué configura cada variable y **procedimiento de rotación**.
- [ ] 7. Accesos por defecto: cómo se crea el ADMIN semilla y de qué variable o secreto sale cada credencial (sin valores reales).

### Otros documentos
- [ ] `docs/arquitectura.md`, con el diagrama (Mermaid/PNG) de componentes, redes y flujos.
- [ ] `docs/eventos.md`, el catálogo final.
- [ ] `docs/guias/`: guías de configuración de RabbitMQ, Jenkins, SonarQube, Grafana/Loki/Prometheus, Zipkin/Jaeger y Keycloak (si se adopta).
- [ ] Justificar en el README las decisiones que se apartan del enunciado: MySQL en departamentos, MailHog como SMTP, la opción (a) de auth, el stack de logs elegido.

---

## Orden de trabajo sugerido (por impacto en la nota)

1. **Observabilidad completa** (15 %, hoy en 0): logs JSON + Loki, `/metrics` + Prometheus/Grafana, OTel + Zipkin con propagación por RabbitMQ, y alertas.
2. **Tests y cobertura** en gateway, auth y departamentos, más los **health checks** con dependencias y 503 (25 %).
3. **Secretos**: quitar defaults, Docker Secrets y `setup-secrets.sh` (restricción obligatoria que puede penalizar directamente).
4. **Estructura de entrega** con `docker-compose.yml` en la raíz y el **README raíz** (restricción obligatoria).
5. **Escalabilidad**: réplicas, load balancer y la demo de caída de una instancia.
6. **Jenkinsfiles** para los 5 servicios restantes, más lint y seguridad.
7. Extras con puntaje adicional: `/empleados/{id}/completo` y Keycloak + JWKS.
