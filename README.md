# Plataforma RHM — infraestructura

Este es el repositorio de infraestructura y orquestación de la plataforma. Los microservicios se
mantienen en repositorios Git independientes; este repositorio solo concentra el Compose, el borde
Nginx, observabilidad, CI, scripts y documentación transversal.

Ejecute el stack desde aquí:

```bash
cp .env.example .env
./scripts/setup-secrets.sh
docker compose up --build -d --wait
```

La entrada pública es `http://localhost:8080` a través de `edge` (Nginx); el contenedor
`api-gateway` no publica puertos directamente. La configuración de Grafana usa el secreto local
`secrets/grafana_admin_password`. Los demás secretos todavía conservan la configuración heredada
por variables de entorno y se migrarán progresivamente; nunca versionar `secrets/` ni `.env`.

Este repositorio contiene el único `docker-compose.yml` del sistema. Levanta el API Gateway, los
microservicios y sus bases de datos aisladas con un solo comando.

| Componente | Tecnología | Puerto host | Volumen / dependencia |
|---|---|---:|---|
| `api-gateway` | Node.js + TypeScript | 8080 | empleados, departamentos, notificaciones, perfiles, vacaciones |
| `empleados-service` | Node.js + TypeScript | interno 8080 (sin publicar) | `database-empleados` |
| `database-empleados` | PostgreSQL 17 | interno 5432 (sin publicar) | `employees-db-data` |
| `departamentos-service` | PHP 8.3 + Apache | interno 80 (sin publicar) | `database-departamentos` |
| `database-departamentos` | MySQL 8.4 | interno 3306 (sin publicar) | `departments-db-data` |
| `message-broker` | RabbitMQ 4 (management) | 5672 (AMQP) y 15672 (UI), solo localhost | `broker-data` |
| `notificaciones-service` | Python + FastAPI | interno 8080 (sin publicar) | `database-notificaciones` |
| `database-notificaciones` | PostgreSQL 17 | interno 5432 (sin publicar) | `notifications-db-data` |
| `perfiles-service` | Go | interno 8080 (sin publicar) | `database-perfiles` |
| `database-perfiles` | PostgreSQL 17 | interno 5432 (sin publicar) | `profiles-db-data` |
| `vacaciones-service` | Ruby + Sinatra | interno 8080 (sin publicar) | `database-vacaciones` |
| `database-vacaciones` | PostgreSQL 17 | interno 5432 (sin publicar) | `vacations-db-data` |
| `auth-service` | Node.js + TypeScript | interno 8080 (sin publicar) | `database-auth` |
| `database-auth` | PostgreSQL 17 | interno 5432 (sin publicar) | `auth-db-data` |
| `mailhog` | MailHog | 8025 (UI), solo localhost | — |
| `jenkins` | Jenkins LTS (JDK 21) — CI, Reto 7 | 9090 | `jenkins-data`, socket Docker del host |
| `sonarqube` | SonarQube 9.9 LTS Community — Reto 7 | 9000 | `sonar-db`, `sonarqube-*` |
| `sonar-db` | PostgreSQL 17 | interno 5432 (sin publicar) | `sonar-db-data` |
| `sonar-init` | one-shot (curl) que aprovisiona SonarQube | — | `sonar-token` |
| `registry` (`docker-registry`) | Docker Registry 2 — Reto 7 | 5000 | `registry-data` |
| `registry-ui` | Interfaz web del Registry | 5080 (solo localhost) | `registry` |

La única entrada HTTP publicada para los microservicios es `http://localhost:8080`, servida por el
Gateway. Dentro de Docker, el Gateway enruta `/empleados/*` a `empleados-service:8080`,
`/departamentos/*` a `departamentos-service:80`, `/notificaciones/*` a
`notificaciones-service:8080`, `/perfiles/*` a `perfiles-service:8080`, `/vacaciones/*` a
`vacaciones-service:8080` y `/auth/*` a `auth-service:8080`. Cada servicio usa su propia base de datos
(`database-empleados:5432`, `database-departamentos:3306`, `database-notificaciones:5432`,
`database-perfiles:5432`, `database-vacaciones:5432`); ningún servicio consulta la base de datos de
otro.

Ninguna base de datos publica su puerto al host: ya no es posible conectarse con `psql`/`mysql`
desde la máquina local a `localhost:5433` o `localhost:3307` como en el Reto 2. Solo `api-gateway`
(puerto `8080`) y `message-broker` (puertos `5672`/`15672`, para su management UI) quedan accesibles
fuera de la red Docker.

## Lenguajes del ecosistema (Reto 4)

El enunciado exige al menos 4 lenguajes distintos en el proyecto final. Este reto los completa:

| Servicio | Lenguaje / framework | Repositorio |
|---|---|---|
| `empleados-service` | Node.js + TypeScript (Express) | [ms-employees](https://github.com/Microservicios-RHM/ms-employees) |
| `departamentos-service` | PHP 8.3 (Apache) | [ms-departments](https://github.com/Microservicios-RHM/ms-departments) |
| `api-gateway` | Node.js + TypeScript (Express) | [api-gateway](https://github.com/Microservicios-RHM/api-gateway) |
| `notificaciones-service` | Python + FastAPI | [ms-notifications](https://github.com/Microservicios-RHM/ms-notifications) |
| `perfiles-service` | Go (biblioteca estándar `net/http`) | [ms-profiles](https://github.com/Microservicios-RHM/ms-profiles) |
| `vacaciones-service` | Ruby + Sinatra | [ms-vacation](https://github.com/Microservicios-RHM/ms-vacation) |
| `auth-service` | Node.js + TypeScript (Express) | [auth-service](https://github.com/Microservicios-RHM/auth-service) |

Cinco lenguajes distintos (Node/TypeScript, PHP, Python, Go, Ruby) — uno más que el mínimo exigido.
Los tres servicios nuevos del Reto 4 (`notificaciones`, `perfiles`, `vacaciones`) están en tres
lenguajes distintos entre sí y distintos de los ya usados en `empleados`/`departamentos`, tal como
pide el enunciado.

## Message broker (Reto 4)

Se evaluaron tres opciones:

- **RabbitMQ** — protocolo AMQP maduro, exchanges/colas con bindings explícitos, UI de
  administración web incluida en la imagen oficial (`rabbitmq:4-management-alpine`), y es la que da
  el propio enunciado como referencia.
- **Kafka** — mayor throughput y retención tipo log, pero requiere operar Zookeeper/KRaft y está
  sobredimensionado para el volumen de este ecosistema (4 tipos de evento, 3 consumidores).
- **NATS** — muy ligero y de baja latencia, pero su consola de administración es más limitada que la
  de RabbitMQ para inspeccionar colas y republicar mensajes manualmente (requisito de la prueba de
  deduplicación).

Se eligió **RabbitMQ** por su UI de administración (necesaria para republicar manualmente un mensaje
y demostrar la deduplicación), su modelo de exchange `topic` que expresa naturalmente el fan-out
(un evento, múltiples colas enlazadas), y por tener clientes maduros en los 5 lenguajes usados en el
ecosistema (Node, PHP, Python, Go, Ruby).

Diseño de exchange/colas y contrato de cada evento: [`docs/event-catalog.md`](docs/event-catalog.md).

**Reto 4 completo.** Los 4 eventos del catálogo tienen productor y consumidores:

- `empleados-service` publica `empleado.creado`, `empleado.actualizado` y `empleado.retirado`.
- `vacaciones-service` (Ruby/Sinatra) publica `vacaciones.programadas` al programar un período
  exitosamente, y consume `empleado.creado`/`empleado.retirado` para su réplica local de empleados
  válidos (justificación de esa decisión en su propio README).
- `notificaciones-service` (Python/FastAPI) consume los 3 eventos que le corresponden
  (`BIENVENIDA`, `DESVINCULACION`, `VACACIONES`).
- `perfiles-service` (Go) consume los 3 eventos de empleado (crea/sincroniza/archiva el perfil).

Deduplicación verificada de punta a punta republicando manualmente mensajes desde la API de
RabbitMQ, en los tres consumidores. Los 5 servicios (`empleados`, `departamentos`,
`notificaciones`, `perfiles`, `vacaciones`) están registrados en el API Gateway.

Acceso a la UI de administración una vez levantado el stack:

```text
http://localhost:15672
Usuario: admin (o el valor de BROKER_USER)
Password: admin (o el valor de BROKER_PASSWORD)
```

### Validación de existencia del empleado en `vacaciones-service`

El enunciado exige justificar esta decisión explícitamente. `vacaciones-service` consume
`empleado.creado`/`empleado.retirado` y mantiene su propia réplica local mínima de empleados
válidos, en vez de consultar `empleados-service` por REST en cada `POST /vacaciones`. Se prioriza
**disponibilidad sobre consistencia inmediata**: programar vacaciones no debe depender de que otro
servicio esté arriba en ese instante. Justificación completa, con la contrapartida (inconsistencia
eventual) documentada sin ocultarla, en el
[README de `ms-vacation`](https://github.com/Microservicios-RHM/ms-vacation#decisión-técnica-validación-de-existencia-del-empleado).

## Inicio

Desde esta carpeta:

```bash
cp .env.example .env
docker compose up --build
```

Verifica el arranque ordenado (los 12 contenedores deben quedar `healthy`; toma un par de minutos
por las migraciones y las dependencias en cadena):

```bash
docker compose ps
```

```text
Gateway:         http://localhost:8080
Empleados:       http://localhost:8080/empleados
Departamentos:   http://localhost:8080/departamentos
Notificaciones:  http://localhost:8080/notificaciones
Perfiles:        http://localhost:8080/perfiles
Vacaciones:      http://localhost:8080/vacaciones
Health Gateway:  http://localhost:8080/health
RabbitMQ (UI):   http://localhost:15672
Jenkins (CI):    http://localhost:9090   (ver "Integración continua", Reto 7)
SonarQube:       http://localhost:9000
Registry API:    http://localhost:5000/v2/_catalog
Registry UI:     http://localhost:5080
```

Ningún microservicio ni base de datos publica su puerto HTTP directamente al host — todos son
alcanzables solo dentro de `microservices-network` (`empleados-service:8080`,
`departamentos-service:80`, `notificaciones-service:8080`, `perfiles-service:8080`,
`vacaciones-service:8080`). El único punto de entrada es el Gateway en `:8080`, más
`message-broker` en `:5672`/`:15672` para inspección manual (management UI, prueba de
deduplicación).

## API Gateway y Circuit Breaker

El cliente externo utiliza únicamente `http://localhost:8080`, publicado por `api-gateway`:

| Ruta pública | Destino interno |
|---|---|
| `/health` | API Gateway |
| `/empleados/*` | `empleados-service:8080` |
| `/departamentos/*` | `departamentos-service:80` |
| `/notificaciones/*` | `notificaciones-service:8080` |
| `/perfiles/*` | `perfiles-service:8080` |
| `/vacaciones/*` | `vacaciones-service:8080` |

Cada servicio monta su Swagger UI y su `openapi.json` bajo su propio prefijo de negocio (el mismo
que ya proxea la tabla de arriba, sin reescritura de ruta), así que quedan alcanzables detrás del
Gateway sin ninguna regla adicional:

```text
http://localhost:8080/empleados/docs
http://localhost:8080/departamentos/docs
http://localhost:8080/notificaciones/docs
http://localhost:8080/perfiles/docs
http://localhost:8080/vacaciones/docs
```

`empleados-service` valida departamentos mediante HTTP y no accede directamente a MySQL. La
operación está protegida por un Circuit Breaker con `opossum`, configurado en el servicio
consumidor:

```dotenv
DEPARTMENTS_CIRCUIT_BREAKER_THRESHOLD=3
DEPARTMENTS_CIRCUIT_BREAKER_RESET_TIMEOUT_MS=30000
DEPARTMENTS_CACHE_TTL_SECONDS=300
```

La caché `node-cache` se mantiene dentro de `empleados-service`: almacena únicamente validaciones
positivas de Departamentos. Ante timeout, error o Circuit Breaker `OPEN`, permite registrar solo si
existe una entrada vigente; sin ella responde `503`. Al ser local por instancia, Redis sería la
evolución necesaria para varias réplicas.

Después de un mínimo de tres operaciones, una tasa de fallo de al menos 50 % en una ventana de
60 segundos abre el circuito. Los retries internos conservan tres intentos, timeout por intento de
2 segundos, backoff y timeout total de 9 segundos; la operación completa cuenta como un único
fallo del Circuit Breaker. Un `404` de departamentos conserva el flujo `DEPARTMENT_NOT_FOUND` con
HTTP 400 y no abre el circuito.

En `OPEN`, no se ejecutan nuevas llamadas a departamentos y el registro responde HTTP 503 con
`DEPARTMENT_SERVICE_UNAVAILABLE`. No se agregó `PENDIENTE_VALIDACION` al modelo ni al esquema de
PostgreSQL porque ese estado no pertenece al dominio actual. Después de 30 segundos, `HALF_OPEN`
permite una llamada de prueba: un éxito devuelve el circuito a `CLOSED` y un fallo lo mantiene en
`OPEN`. Las transiciones y los fallos se registran con Pino en `empleados-service`.

Para reproducir la prueba controlada sin eliminar volúmenes:

```bash
docker compose stop departamentos-service
# realizar tres POST /empleados mediante http://localhost:8080
# cada operación debe mostrar los retries y responder 503
# una solicitud posterior debe ser rechazada rápidamente por el circuito OPEN
docker compose start departamentos-service
docker compose ps
```

Después del reset timeout, una solicitud válida debe demostrar `HALF_OPEN` y recuperación a
`CLOSED`. Las pruebas deterministas del Circuit Breaker se ejecutan desde `ms-employees` con
`npm test`.

## Prueba del flujo asincrónico completo (Reto 4)

Con el stack levantado (`docker compose up --build`), este es el flujo real — capturado contra el
sistema en ejecución, no simulado — que un mismo `empleado.creado` dispara en cascada, cierra con
un retiro, y demuestra el fan-out hacia los tres consumidores nuevos.

```bash
# 1. Crear el empleado
curl -s -X POST http://localhost:8080/empleados -H "Content-Type: application/json" \
  -d '{"id":"E950","nombre":"Verónica","apellido":"Salas","email":"veronica.salas@empresa.com",
       "numeroEmpleado":"EMP-2026-950","cargo":"HR Analyst","area":"Recursos Humanos",
       "departamentoId":"IT","fechaIngreso":"2026-08-15"}'

# 2. El perfil se creó solo, vía empleado.creado (perfiles-service)
curl -s http://localhost:8080/perfiles/E950
# → {"data":{"empleadoId":"E950","nombre":"Verónica","email":"...","archivado":false,...}}

# 3. La notificación de bienvenida se registró sola, vía empleado.creado (notificaciones-service)
curl -s http://localhost:8080/notificaciones/E950
# → [{"tipo":"BIENVENIDA","destinatario":"veronica.salas@empresa.com",...}]

# 4. Programar vacaciones (vacaciones-service valida el empleado contra su réplica local,
#    sin llamar a empleados-service; luego publica vacaciones.programadas)
curl -s -X POST http://localhost:8080/vacaciones -H "Content-Type: application/json" \
  -d '{"empleadoId":"E950","fechaInicio":"2026-10-20","fechaFin":"2026-10-27"}'
# → {"data":{"id":"V-2026-0003","estado":"PROGRAMADA",...}}

# 5. La confirmación de vacaciones se registró sola, vía vacaciones.programadas
curl -s http://localhost:8080/notificaciones/E950
# → ahora incluye {"tipo":"VACACIONES","mensaje":"Sus vacaciones del 2026-10-20 al 2026-10-27
#    han sido confirmadas, Verónica Salas.",...}

# 6. Retirar al empleado (baja lógica: nunca se borra, cambia de estado)
curl -s -X DELETE http://localhost:8080/empleados/E950
# → {"data":{"estado":"RETIRADO","fechaRetiro":"2026-09-30T10:55:38.018Z",...}}

# 7. Auditoría de retiros
curl -s "http://localhost:8080/empleados?estado=RETIRADO"
# → incluye E950

# 8. El perfil se archivó solo (no se borró), vía empleado.retirado
curl -s http://localhost:8080/perfiles/E950
# → {"data":{"archivado":true,...}}

# 9. La notificación de desvinculación se registró sola, vía empleado.retirado
curl -s http://localhost:8080/notificaciones/E950
# → ahora incluye {"tipo":"DESVINCULACION",...} — 3 notificaciones en total para E950
```

Cada uno de los pasos 2, 3, 5, 8 y 9 ocurre **sin que el cliente llame nada más que el paso
anterior** — son efectos asincrónicos de los eventos, verificables porque cada respuesta llega ya
con los datos aplicados.

## Evidencia de deduplicación (Reto 4)

Verificación exigida por el enunciado: republicar manualmente el mismo mensaje dos veces desde la
UI de administración del broker y demostrar que solo se registra un efecto.

Sobre el flujo anterior, se tomó el `id` real del mensaje `empleado.retirado` de E950 de los logs
de `empleados-service` y se republicó **el mismo id** vía la API de administración de RabbitMQ
(equivalente a "Publish message" desde la UI en `http://localhost:15672`):

```bash
curl -s -u admin:admin -X POST http://localhost:15672/api/exchanges/%2f/rhm.events/publish \
  -H "Content-Type: application/json" \
  -d '{"properties":{"content_type":"application/json","delivery_mode":2,
       "message_id":"cd52e7ef-dae2-48e6-a79e-fbfa9c6e93c0"},
       "routing_key":"empleado.retirado","payload":"<mismo payload, mismo id>",
       "payload_encoding":"string"}'
```

Ese `empleado.retirado` tiene **dos** consumidores enlazados por fan-out
(`notificaciones-service` y `perfiles-service`); la prueba real disparó ambos a la vez:

```text
notificaciones-service:
{"level":"info","msg":"Duplicate event ignored","eventId":"cd52e7ef-...","eventType":"empleado.retirado"}

perfiles-service:
{"level":"info","msg":"duplicate event ignored","eventId":"cd52e7ef-...","eventType":"empleado.retirado"}
```

Conteo de notificaciones de E950 antes y después de republicar: **3 en ambos casos** — ningún
`DESVINCULACION` adicional se creó, y el perfil de E950 siguió con un único registro archivado.
Los tres consumidores nuevos (`notificaciones`, `perfiles`, `vacaciones`) implementan el mismo
patrón atómico (`INSERT ... ON CONFLICT DO NOTHING RETURNING id` sobre `eventos_procesados`,
seguido del efecto, en una sola transacción), documentado con más detalle en el README de cada
servicio.

## Seguridad y control de acceso (Reto 5)

Todos los endpoints exigen ahora un token JWT en la cabecera `Authorization: Bearer <token>`. La
validación se hace **en el API Gateway**, una sola vez, y no con un interceptor por servicio: el
ecosistema tiene seis servicios en cinco lenguajes, y repartir la verificación de firma
significaría mantener sincronizadas cinco implementaciones de lo mismo.

El proveedor de identidad es [`auth-service`](https://github.com/Microservicios-RHM/auth-service),
que además gobierna el ciclo de vida de las cuentas a partir de los eventos del broker: crea la
cuenta cuando se da de alta un empleado, la suspende cuando empiezan sus vacaciones, la reactiva
cuando terminan y la da de baja cuando lo retiran.

Para obtener un token de prueba:

```bash
curl -s -X POST http://localhost:8080/auth/login   -H "Content-Type: application/json"   -d '{"username":"admin","password":"change_admin_password"}'
```

Esa cuenta administradora se crea sola al arrancar. Sin ella nadie podría crear el primer empleado,
porque todos los endpoints de escritura exigen rol `ADMIN`.

| Rol | Puede |
|---|---|
| `ADMIN` | Todo |
| `USER` | Leer cualquier recurso, cambiar su propia contraseña y editar **su propio** perfil |

Sin token válido se responde `401`; con token pero sin permiso, `403`.

**El detalle completo está en [docs/reto-5-seguridad.md](docs/reto-5-seguridad.md)**: la
justificación de la estrategia elegida, el manejo del secreto JWT, el diagrama de secuencia del
ciclo de vida de la cuenta, el scheduler de vacaciones con su limitación conocida, y la evidencia
del caso borde del empleado retirado durante sus vacaciones.

## Integración continua con Jenkins (Reto 7)

### Qué es CI y por qué está aquí

La integración continua consiste en que **cada cambio** que llega al repositorio se compila, se
prueba y se empaqueta automáticamente, en un entorno limpio, en minutos. Hasta el Reto 6 todo eso
era manual: si alguien rompía las pruebas de `ms-vacation`, nadie lo sabía hasta el siguiente
`docker compose up`, y los reportes del Reto 6 se quedaban en el disco de quien los generó.

Ahora cada microservicio con pruebas tiene un `Jenkinsfile` versionado junto a su código, y Jenkins
publica todos los reportes en su interfaz: qué prueba falló, cuánta cobertura hay y cómo cambia
entre builds, y qué escenario de negocio se rompió.

```text
git push ─▶ Jenkins (pollSCM) ─▶ Checkout ─▶ Build ─▶ Test ─▶ SonarQube ─▶ Quality Gate ─▶ Package ─▶ Publish ─▶ E2E Tests
                                                       │                      │               │           │           │
                                              Test Result + Coverage     falla si < 70 %   imagen     registry   Cucumber Reports
                                                                                           Docker     :5000      + logs del stack
```

### Acceso

| Herramienta | URL | Usuario | Contraseña (por defecto, ver `.env`) |
|---|---|---|---|
| Jenkins | http://localhost:8090 | `admin` | `rhmUQ` |
| SonarQube | http://localhost:9000 | `admin` | `rhmUQ` (`admin/admin` se reemplaza solo) |
| Registry | http://localhost:5000/v2/_catalog | — | — |

Las URLs se configuran en `.env`; sin definirlas se usan los valores de la tabla:

| Variable | Por defecto | Para qué |
|---|---|---|
| `JENKINS_PUBLIC_URL` | `http://localhost:${JENKINS_HOST_PORT}/` | URL de Jenkins en los enlaces que genera |
| `SONAR_PUBLIC_URL` | `http://localhost:${SONAR_HOST_PORT}` | Enlace "SonarQube" de cada build (`sonar.core.serverBaseURL`) |
| `SONAR_INTERNAL_URL` | `http://sonarqube:9000` | Jenkins, el scanner y `sonar-init` hablan con SonarQube |
| `SONAR_WEBHOOK_URL` | `http://jenkins:8080/sonarqube-webhook/` | Aviso de SonarQube que espera `waitForQualityGate` |
| `RHM_REGISTRY` | `localhost:${REGISTRY_HOST_PORT}` | Registry donde publica la etapa Publish |
| `E2E_BASE_URL` | `http://api-gateway:8080` | API Gateway del stack efímero para la suite BDD |

### Puesta en marcha

#### a. Levantar el sistema con Jenkins incluido

```bash
cp .env.example .env          # la primera vez; las variables del Reto 7 están al final
docker compose up --build -d
```

El orden de arranque lo resuelve Compose: `sonar-db` → `sonarqube` → `sonar-init` (aprovisiona
SonarQube y termina) → `jenkins`. Jenkins tarda 2–4 minutos la primera vez porque espera a que
SonarQube esté listo; se puede seguir con `docker compose logs -f sonar-init jenkins`.

Requisitos del host: Docker Engine con Compose ≥ 2.24, ~6 GB de RAM libres para todo el stack y
**al menos 10 % de disco libre**: el Elasticsearch interno de SonarQube pone sus índices en solo
lectura al pasar del 95 % de uso del disco, y los análisis fallan con
`Unrecoverable indexation failures` en la etapa Quality Gate.

#### b. Contraseña inicial de Jenkins

No hay contraseña inicial que buscar: el Setup Wizard está desactivado
(`-Djenkins.install.runSetupWizard=false`) y el administrador lo crea JCasC con
`JENKINS_ADMIN_USER` / `JENKINS_ADMIN_PASSWORD` del `.env`. Si se reactivara el wizard (quitando esa
opción de `JAVA_OPTS`), la contraseña generada se obtiene con:

```bash
docker exec jenkins cat /var/jenkins_home/secrets/initialAdminPassword
```

#### c. Crear / importar los pipelines

No hay que hacer nada: los jobs se aprovisionan como código al arrancar Jenkins
(`jenkins/casc.yaml`, bloque `jobs:` con Job DSL).

| Job | Qué es | Origen del pipeline |
|---|---|---|
| `verificacion-docker` | Punto 1: comprueba `docker --version`, `docker compose version` y `docker ps` desde Jenkins | inline en `casc.yaml` |
| `ms-employees` | CI de empleados-service (Node.js 24 + TypeScript) | `Jenkinsfile` de [ms-employees](https://github.com/Microservicios-RHM/ms-employees) |
| `ms-vacation` | CI de vacaciones-service (Ruby 3.4 + Sinatra) | `Jenkinsfile` de [ms-vacation](https://github.com/Microservicios-RHM/ms-vacation) |

Los jobs leen el `Jenkinsfile` de `RHM_GIT_BASE_URL/<repo>.git`, rama `RHM_GIT_BRANCH` (por defecto
`main`). Para probar una rama de trabajo antes de mezclarla: `RHM_GIT_BRANCH=feat/reto-7` en `.env` y
`docker compose up -d jenkins`. Agregar un servicio = agregar su nombre a la lista del bloque `jobs:`.

#### d. Ejecutar un pipeline manualmente

Jenkins → job (`ms-employees` o `ms-vacation`) → **Build Now**. La vista de etapas aparece en la
página del job; el detalle de cada build en **Pipeline Overview**. Además, cada Jenkinsfile declara
`pollSCM('H/5 * * * *')`: tras la primera ejecución, Jenkins revisa el repositorio cada ~5 minutos y
lanza un build si hay commits nuevos (sin webhook, porque GitHub no alcanza un Jenkins local).

### Etapas del pipeline

| Etapa | Dónde corre | Qué verifica | Si falla |
|---|---|---|---|
| Checkout | Jenkins | Obtiene el commit y calcula la etiqueta de imagen `<build>-<sha7>` | FAILURE |
| Build | agente Docker efímero (`node:24-alpine` / `ci/agent.Dockerfile` de Ruby) | Dependencias (`npm ci` / `bundle install`), typecheck + compilación TS / sintaxis Ruby y carga de `app/` | FAILURE |
| Test | mismo agente + socket Docker | Unitarias + integración del Reto 6 (Testcontainers / PostgreSQL desechable); publica resultados y cobertura | UNSTABLE si hay pruebas fallidas; FAILURE si no hay reporte |
| SonarQube | agente `sonarsource/sonar-scanner-cli:11` en `microservices-network` | Envía código + reporte de cobertura (SonarQube no ejecuta pruebas) | FAILURE |
| Quality Gate | Jenkins (espera el webhook) | Gate `RHM`: cobertura ≥ 70 %, y en código nuevo cobertura ≥ 70 %, duplicación ≤ 3 %, calificaciones A | FAILURE (`abortPipeline: true`) |
| Package | Jenkins → Docker del host | `docker build` del Dockerfile multi-stage: `rhm/<servicio>:<build>-<sha7>` y `:latest` | FAILURE |
| Publish | Jenkins → registry | Push a `localhost:5000/rhm/<servicio>` (ambas etiquetas) | FAILURE |
| E2E Tests | Jenkins + agente `node:24-alpine` | Levanta el sistema completo **aislado**, con la imagen recién construida, y corre la suite BDD del Reto 6 | UNSTABLE si falla un escenario; FAILURE si el sistema no arranca |

### Reportes publicados

| Etapa | Reporte | Archivo | Paso del Jenkinsfile | Dónde se consulta en Jenkins |
|---|---|---|---|---|
| Test | Resultados unitarios + integración | `reports/junit.xml` | `junit` | Build → **Tests** (detalle por prueba con mensaje y stack trace) · página del job → gráfica de tendencia de pruebas |
| Test | Cobertura | `reports/lcov.info` (Node) · `reports/coverage.xml` (Ruby, Cobertura) | `recordCoverage` (parser `LCOV` / `COBERTURA`) | Build → **Cobertura (unitarias + integración)** (por paquete/archivo, código fuente coloreado, delta vs. build anterior) · tendencia en la página del job |
| Test (Ruby) | Cobertura navegable de SimpleCov | `reports/index.html` | `publishHTML` | Build → **Cobertura SimpleCov** |
| SonarQube | Bugs, vulnerabilidades, code smells, duplicación, cobertura | — | `withSonarQubeEnv` + `sonar-scanner` | Enlace **SonarQube** en el build → dashboard en http://localhost:9000 |
| Quality Gate | Estado Passed/Failed | — | `waitForQualityGate` | Log de la etapa y badge de SonarQube en el build |
| E2E Tests | Resultados por escenario | `.e2e/e2e-tests/reports/junit.xml` | `junit` | Build → **Tests** (suite `e2e-tests (BDD)`) |
| E2E Tests | Características y escenarios en español, paso a paso | `.e2e/e2e-tests/reports/cucumber.json` | `cucumber` | Build → **Cucumber reports** |
| E2E Tests | Reporte HTML de Cucumber (con la última respuesta HTTP de cada escenario fallido) | `.e2e/e2e-tests/reports/cucumber.html` | `publishHTML` | Build → **Reporte BDD** |
| E2E Tests | Logs de todos los contenedores del stack | `.e2e/e2e-docker-logs.txt` | `archiveArtifacts` | Build → **Build Artifacts** |

Todos se publican en bloques `post { always { } }`: se ven también cuando las pruebas fallan, que
es justamente cuando más se necesitan.

### Cómo interpretar los resultados

| Color | Estado | Significado | ¿Sigue el pipeline? |
|---|---|---|---|
| 🟢 Verde | `SUCCESS` | Todo pasó | — |
| 🟡 Amarillo | `UNSTABLE` | El código compila, pero hay pruebas o escenarios BDD fallando. `junit` / `cucumber` marcan el estado | No: `skipStagesAfterUnstable()` salta las etapas siguientes (aparecen grises) |
| 🔴 Rojo | `FAILURE` | Algo impidió verificar: no compila, falta el reporte, el Quality Gate no pasa, el Dockerfile no construye o el stack no arranca | No |
| ⚪ Gris | etapa omitida | Se saltó por un fallo o inestabilidad anterior | — |

**FAILURE vs. UNSTABLE.** Se adoptó la convención: una prueba fallida es UNSTABLE (el código es
verificable y el reporte dice exactamente qué falló) y todo lo demás es FAILURE. Aun así, un servicio
con pruebas fallidas **no llega a Package**: `skipStagesAfterUnstable()` detiene el pipeline en Test.
Un build amarillo nunca produce una imagen.

### Fallos simulados (Punto 5)

Cada fallo se introdujo en un commit aparte y se ejecutó el pipeline correspondiente:

| Fallo introducido | Etapa donde se detuvo | Estado | Qué muestra Jenkins (sin abrir la consola) |
|---|---|---|---|
| `ms-employees`: en `tests/unit/retire-employee.use-case.test.ts` se esperaba `'ACTIVO'` en lugar de `'RETIRADO'` | Test (SonarQube, Quality Gate, Package, Publish y E2E omitidas) | 🟡 UNSTABLE | **Tests**: `transiciona ACTIVO -> RETIRADO registrando fechaRetiro y publica empleado.retirado` — `Expected values to be strictly equal: + 'RETIRADO' - 'ACTIVO'` |
| `ms-vacation`: se borraron `spec/application`, `spec/domain` y `spec/infrastructure` (cobertura 12,2 %) | Quality Gate (Package, Publish y E2E omitidas) | 🔴 FAILURE | `Quality gate is 'ERROR'`; en SonarQube la condición *Coverage* aparece en rojo: 12,2 < 70 |
| `ms-vacation`: `FROM ruby:3.4-alpinee` en el Dockerfile | Package | 🔴 FAILURE | Log de Package: `ruby:3.4-alpinee: not found` |
| `e2e-tests`: en `seguridad.feature` se esperaba `201` donde el sistema responde `403` | E2E Tests | 🟡 UNSTABLE | **Cucumber reports**: característica *Seguridad y control de acceso* en rojo. **Tests**: `Seguridad y control de acceso › Un usuario con rol USER puede consultar pero no modificar` — `Se esperaba el código 201 y se obtuvo 403. POST /empleados → 403 {... "code":"FORBIDDEN"}` |

Hallazgo de esa prueba: mientras el Dockerfile de `ms-vacation` estaba roto, el E2E de
`ms-employees` también falló (FAILURE, no UNSTABLE), porque el stack E2E construye los demás
servicios desde su rama y `vacaciones-service` no compilaba. Es el comportamiento buscado: un cambio
que rompe un servicio se detecta también en los pipelines de los demás.

### Decisiones técnicas

**Jenkins (Punto 1)**

- **Imagen propia** (`jenkins/Dockerfile`) sobre `jenkins/jenkins:lts-jdk21`, con los plugins de
  `jenkins/plugins.txt` instalados por `jenkins-plugin-cli`: además de los mínimos (`workflow-aggregator`,
  `docker-workflow`, `git`, `configuration-as-code`, `job-dsl`), los de reportes (`junit`, `coverage`,
  `cucumber-reports`, `htmlpublisher`), `sonar`, `credentials`/`plain-credentials`, `timestamper`,
  `ws-cleanup` y `pipeline-graph-view`. El id real del plugin "Docker Pipeline" es `docker-workflow`.
- **Cliente Docker**: se copian los binarios estáticos de `docker:29-cli` (cliente + plugins
  `compose` y `buildx`) en lugar de `apt-get install docker.io`, que instala un daemon que no se usa y
  no trae `docker compose`, necesario para la etapa E2E.
- **Socket montado, no DinD**: más simple y reutiliza la caché de imágenes del host. Riesgo asumido
  (quien controla Jenkins controla el Docker del host), aceptable en un entorno académico.
- **Permisos del socket, sin root**: el GID del grupo dueño de `/var/run/docker.sock` cambia entre
  máquinas (968 en una, 999 en otra), así que no se puede fijar al construir la imagen como en el
  ejemplo del enunciado (`groupadd docker` crea un GID que no coincide). Se define en `.env` como
  `DOCKER_GID` (`stat -c %g /var/run/docker.sock`) y el servicio `jenkins` lo recibe con `group_add`.
  Así la imagen termina en `USER jenkins` y el contenedor nunca corre como root (regla de SonarQube
  "no ejecutar contenedores como root"). Jenkins expone `DOCKER_GID` como variable de entorno y los
  Jenkinsfile la pasan con `--group-add` a los agentes que también usan el socket.
- **Setup Wizard desactivado**: con plugins y administrador definidos como código, el wizard solo
  agregaría un paso manual.
- **CSP relajado** (`-Dhudson.model.DirectoryBrowserSupport.CSP=`): sin esto Jenkins bloquea el
  JavaScript de `cucumber.html` y del reporte de SimpleCov y se ven en blanco.

**Pipelines (Punto 2)**

- **Aprovisionamiento con JCasC + Job DSL** (opción A). Todo lo configurable está en un archivo
  versionado (`jenkins/casc.yaml`) que se aplica en cada arranque: usuario, credenciales, servidor
  SonarQube, variables globales y jobs. Se copia dentro de la imagen (no se monta) para que el
  stack no dependa de rutas del host; cambiarlo requiere `docker compose up -d --build jenkins`.
  Se prefirió sobre `init.groovy.d` porque es declarativo e idempotente, y sobre Jenkinsfile local
  (opción C) porque un CI debe construir lo que está en el repositorio, no el disco de alguien.
- **Agentes Docker efímeros** con `reuseNode true`: cada etapa corre en la imagen de su lenguaje y
  Jenkins no necesita Node ni Ruby instalados. El plugin detecta que Jenkins está en un contenedor y
  monta su volumen en el agente (`--volumes-from`), así que el workspace es el mismo.
- **Cachés de dependencias** dentro del volumen `jenkins-data` (`/var/jenkins_home/caches/{npm,bundle,sonar}`),
  visibles en todos los agentes por ese mismo `--volumes-from`. `npm ci` y `bundle install` no
  descargan todo en cada build.
- **Pruebas de integración en CI**: el agente de Test recibe el socket Docker, `--group-add $DOCKER_GID`
  y `--network host`, de modo que el PostgreSQL desechable que publica Testcontainers (Node) o
  `spec/support/postgres_container.rb` (Ruby) en `127.0.0.1:<puerto>` es alcanzable igual que en
  la máquina del desarrollador. El agente de Ruby es `ms-vacation/ci/agent.Dockerfile`: la imagen de
  Ruby más el cliente Docker.

**SonarQube (Punto 3)**

- **Token**: lo genera `sonar-init` (tipo *Global Analysis Token*) y lo deja en el volumen
  `sonar-token`, que Jenkins monta en solo lectura; JCasC lo registra como credencial
  `sonarqube-token` (`${readFile:/run/sonar/token}`). No está en ningún Jenkinsfile, `.env` ni
  repositorio. Si el token deja de ser válido, `sonar-init` lo revoca y genera otro.
- **Quality Gate personalizado `RHM`**, marcado por defecto: `coverage < 70` (sobre todo el código,
  porque en el primer análisis las condiciones de código nuevo no se evalúan), y en código nuevo
  `new_coverage < 70`, `new_duplicated_lines_density > 3` y calificaciones de confiabilidad,
  seguridad y mantenibilidad peores que A.
- **Webhook** `http://jenkins:8080/sonarqube-webhook/`, creado por `sonar-init`. Ambos contenedores
  están en `microservices-network`.
- **Scanner**: imagen `sonarsource/sonar-scanner-cli:11` como agente (trae Java y Node), igual para
  cualquier lenguaje; la configuración de cada servicio va en su `sonar-project.properties`.
- **Ajustes por lenguaje**: el analizador de TypeScript de SonarQube 9.9 LTS no entiende varias
  opciones del `tsconfig.json` de `ms-employees` (`es2024`, `erasableSyntaxOnly`...), así que el análisis
  usa `tsconfig.sonar.json`. El analizador de Ruby lee el JSON de SimpleCov, por lo que
  `ms-vacation` genera además `reports/coverage.json`. En ambos casos `sonar.coverage.exclusions`
  repite las exclusiones de la herramienta local, para que el porcentaje coincida.
- Todo el aprovisionamiento (contraseña, gate, proyectos, webhook, token) está en `sonarqube/init.sh`
  y es idempotente.

**Empaquetado y E2E (Punto 4)**

- **Nombres de imagen**: `rhm/<repositorio>:<BUILD_NUMBER>-<sha7>` y `:latest`. El número ordena los
  builds y el hash dice exactamente qué commit contiene la imagen.
- **Multi-stage**: los Dockerfile de ambos servicios ya lo eran (compilación/gemas en una etapa,
  runtime mínimo en otra). El pipeline solo ejecuta `docker build`; la etapa de Test no se repite
  dentro de la imagen.
- **Registry local** (`registry:2`, puerto 5000). El daemon trata `localhost:5000` como registry
  inseguro permitido, así que no requiere TLS ni credenciales. Con un registry externo (Docker Hub)
  el push iría dentro de `withCredentials` / `docker.withRegistry` con una credencial de Jenkins.
- **Stack E2E aislado**: el `docker-compose.yml` de desarrollo fija nombres de contenedor, volúmenes,
  red y puertos; levantarlo tal cual chocaría con el stack del equipo y `down -v` borraría sus datos.
  La etapa usa un proyecto Compose propio (`COMPOSE_PROJECT_NAME=rhm-e2e-<servicio>`) más
  `ci/docker-compose.e2e.yml`, que con `!reset`/`!override` quita nombres fijos y puertos publicados,
  renombra volúmenes y red, y deja fuera Jenkins/SonarQube/registry. Dos pipelines pueden correr su
  E2E a la vez, y con el stack de desarrollo arriba.
- **La imagen bajo prueba** es la de Package: el Jenkinsfile genera un override con
  `image: rhm/<servicio>:<tag>` y `build: !reset null`. Los demás servicios se construyen desde sus
  repositorios (`ci/checkout-stack.sh`, rama `RHM_GIT_BRANCH` o la por defecto).
- **Rutas del host**: Jenkins usa el Docker del host, que resuelve los bind mounts en el disco del
  host, donde no existe el workspace de Jenkins. El único bind mount del compose (scripts de
  inicialización de MySQL de departamentos) se reemplaza en el override por una imagen derivada con
  `dockerfile_inline`, cuyo contexto sí lo envía el cliente.
- **Espera antes de las pruebas**: `docker compose up --wait --wait-timeout 300`, que espera a que
  todos los healthchecks estén en verde (las dependencias ya usan `depends_on: condition:
  service_healthy`). Además, el primer paso de la suite hace polling sobre `/health` del Gateway.
- **Aislamiento de datos**: cada build empieza con `down -v` (por si un build abortado dejó restos)
  y termina con `down -v` en `post { always }`. La suite, además, usa identificadores únicos por
  ejecución (Reto 6).
- **Rescate de los reportes BDD**: la suite corre con `docker.image('node:24-alpine').inside(...)`,
  unida a la red del stack E2E. Comparte el workspace con Jenkins, así que los reportes quedan en
  `.e2e/e2e-tests/reports` sin `docker cp` ni volúmenes adicionales.
- **Si el sistema no arranca** no hay reporte y `junit` falla por no encontrarlo
  (`allowEmptyResults: false`). Es deliberado: un sistema que no levanta es un FAILURE, no "0 pruebas
  ejecutadas". Antes de eso, los logs de todos los contenedores ya quedaron archivados.

**Reproducibilidad (Punto 5)**

- Pipelines idempotentes: stack E2E con nombre fijo por job y `down -v` antes y después,
  `disableConcurrentBuilds()`, workspace E2E (`.e2e/`) recreado en cada build, etiquetas numeradas
  borradas localmente al final (quedan en el registry). Las pruebas no dependen de datos previos.

### Capturas

> Las capturas se toman de una ejecución real y se guardan en `docs/img/reto7/`.

| Captura | Archivo |
|---|---|
| Pipeline exitoso (vista de etapas) | ![Pipeline exitoso](docs/img/reto7/pipeline-exitoso.png) |
| Pestaña Tests con las pruebas unitarias | ![Test Result](docs/img/reto7/test-result.png) |
| Pestaña de cobertura | ![Coverage](docs/img/reto7/coverage.png) |
| Reporte BDD navegable (características y escenarios en español) | ![Cucumber Reports](docs/img/reto7/cucumber-reports.png) |
| Build fallido con la prueba / escenario identificado | ![Build fallido](docs/img/reto7/build-fallido.png) |
| Dashboard de SonarQube con el Quality Gate | ![SonarQube](docs/img/reto7/sonarqube.png) |

### Estructura agregada

```text
rhm-database-infrastructure/
├── jenkins/
│   ├── Dockerfile         ← imagen de Jenkins: plugins + cliente Docker + JCasC
│   ├── plugins.txt        ← plugins preinstalados
│   └── casc.yaml          ← usuario, credenciales, SonarQube, variables y jobs (JCasC + Job DSL)
├── sonarqube/
│   └── init.sh            ← contraseña, Quality Gate, proyectos, webhook y token (idempotente)
└── ci/
    ├── docker-compose.e2e.yml  ← override del stack efímero de la etapa E2E
    └── checkout-stack.sh       ← clona los demás repositorios para la etapa E2E

ms-employees/   Jenkinsfile, sonar-project.properties, tsconfig.sonar.json
ms-vacation/    Jenkinsfile, sonar-project.properties, ci/agent.Dockerfile
```

## Persistencia

```bash
docker compose down
docker compose up -d
```

Los datos sobreviven porque viven en los volúmenes. Para eliminarlos deliberadamente y recrear
todas las bases desde cero:

```bash
docker compose down -v
docker compose up --build
```

Empleados aplica migraciones versionadas al iniciar. Departamentos usa el script reproducible
`ms-departments/database/init/01_schema.sql`, ejecutado por MySQL al crear un volumen vacío.

## Decisiones de arquitectura

### Motor de base de datos por servicio

La plataforma usa PostgreSQL 17 para Empleados y MySQL 8.4 para Departamentos. Esta persistencia
políglota aprovecha la independencia de los microservicios: cada servicio puede elegir y evolucionar
su persistencia sin compartir tablas ni contratos internos. A cambio, el equipo debe operar,
monitorear, respaldar y actualizar dos motores distintos.

### Creación y evolución del esquema

Cada servicio es dueño de su esquema. Empleados aplica migraciones versionadas e idempotentes al
arrancar. Departamentos tiene un script de creación inicial que MySQL ejecuta solo con un volumen
vacío. Cuando haya datos, cualquier cambio debe aplicarse mediante una migración incremental y
versionada; nunca mediante `docker compose down -v`, porque ese comando elimina los datos.

### Garantía de unicidad

En Empleados, las consultas previas permiten devolver mensajes claros para `email` y
`numeroEmpleado` duplicados. PostgreSQL mantiene restricciones `UNIQUE` como garantía definitiva:
si dos solicitudes simultáneas superan la consulta previa, solo una inserción se confirma y la otra
violación de restricción se traduce a `400`. Departamentos protege su identificador con clave
primaria en MySQL.

## Comandos útiles

```bash
docker compose logs -f empleados-service
docker compose logs -f departamentos-service
docker compose logs -f notificaciones-service
docker compose logs -f perfiles-service
docker compose logs -f vacaciones-service
docker compose logs -f message-broker
docker compose logs -f sonar-init jenkins     # arranque de la CI
docker compose up -d --build jenkins          # aplicar cambios de jenkins/casc.yaml o plugins.txt
```
