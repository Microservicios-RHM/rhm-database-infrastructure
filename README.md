# Plataforma RHM — infraestructura

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

La única entrada HTTP publicada para los microservicios es `http://localhost:8080`, servida por el
Gateway. Dentro de Docker, el Gateway enruta `/empleados/*` a `empleados-service:8080`,
`/departamentos/*` a `departamentos-service:80`, `/notificaciones/*` a
`notificaciones-service:8080`, `/perfiles/*` a `perfiles-service:8080` y `/vacaciones/*` a
`vacaciones-service:8080`. Cada servicio usa su propia base de datos
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
```

Después de un mínimo de tres operaciones, una tasa de fallo de al menos 50 % en una ventana de
30 segundos abre el circuito. Los retries internos conservan tres intentos, timeout por intento de
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
```
