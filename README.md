# Plataforma RHM — infraestructura

Este repositorio contiene el único `docker-compose.yml` del sistema. Levanta el API Gateway, los
dos microservicios y sus bases de datos aisladas con un solo comando.

| Componente | Tecnología | Puerto host | Volumen / dependencia |
|---|---|---:|---|
| `api-gateway` | Node.js + TypeScript | 8080 | ambos microservicios |
| `empleados-service` | Node.js + TypeScript | interno 8080 | `database-empleados` |
| `database-empleados` | PostgreSQL 17 | 5433, solo localhost | `employees-db-data` |
| `departamentos-service` | PHP 8.3 + Apache | interno 80 | `database-departamentos` |
| `database-departamentos` | MySQL 8.4 | 3307, solo localhost | `departments-db-data` |

La única entrada HTTP publicada para los microservicios es `http://localhost:8080`, servida por el
Gateway. Dentro de Docker, el Gateway enruta `/empleados/*` a `empleados-service:8080` y
`/departamentos/*` a `departamentos-service:80`. Empleados usa `database-empleados:5432` y
departamentos usa `database-departamentos:3306`; ningún servicio consulta la base de datos del otro.

## Inicio

Desde esta carpeta:

```bash
cp .env.example .env
docker compose up --build
```

Verifica el arranque ordenado:

```bash
docker compose ps
```

Las dos bases deben mostrar el estado `healthy`. Los servicios dependen de ese estado; empleados
también espera a que departamentos esté saludable.

```text
Gateway:                 http://localhost:8080
Empleados por Gateway:   http://localhost:8080/empleados
Departamentos por Gateway: http://localhost:8080/departamentos
Health Gateway:           http://localhost:8080/health

Los servicios no publican puertos HTTP directamente al host. Sus puertos internos son
`empleados-service:8080` y `departamentos-service:80`.

## API Gateway y Circuit Breaker

El cliente externo utiliza únicamente `http://localhost:8080`, publicado por `api-gateway`:

| Ruta pública | Destino interno |
|---|---|
| `/health` | API Gateway |
| `/empleados/*` | `empleados-service:8080` |
| `/departamentos/*` | `departamentos-service:80` |

`empleados-service` valida departamentos mediante HTTP y no accede directamente a MySQL. La
operación está protegida por un Circuit Breaker con `opossum`, configurado en el servicio
consumidor:

```dotenv
DEPARTMENTS_CIRCUIT_BREAKER_THRESHOLD=3
DEPARTMENTS_CIRCUIT_BREAKER_RESET_TIMEOUT_MS=30000
```

Los tres fallos definitivos consecutivos abren el circuito. Los retries internos conservan tres
intentos, timeout por intento de 2 segundos, backoff y timeout total de 9 segundos; la operación
completa cuenta como un único fallo del Circuit Breaker. Un `404` de departamentos conserva el
flujo `DEPARTMENT_NOT_FOUND` con HTTP 400 y no abre el circuito.

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
```

## Persistencia

```bash
docker compose down
docker compose up -d
```

Los datos sobreviven porque viven en los volúmenes. Para eliminarlos deliberadamente y recrear
ambas bases desde cero:

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
docker compose logs -f database-empleados
docker compose logs -f database-departamentos
```
