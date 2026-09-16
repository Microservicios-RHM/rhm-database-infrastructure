# Plataforma RHM — infraestructura del Reto 2

Orquestación incremental del sistema de Recursos Humanos. En esta primera etapa contiene el
microservicio de empleados y su base de datos exclusiva. Departamentos se incorporará después.

## Componentes actuales

| Servicio | Tecnología | Puerto host | Dependencia |
|---|---|---:|---|
| `empleados-service` | Node.js / TypeScript | 8080 | `database-empleados` |
| `database-empleados` | PostgreSQL 17 | 5433 (solo localhost) | `employees-db-data` |

Dentro de Docker, empleados se conecta a `database-empleados:5432`. La publicación en
`127.0.0.1:5433` existe únicamente para desarrollo local y DBeaver.

## Inicio desde cero

```bash
cp .env.example .env
docker compose up --build
```

Verificar el arranque ordenado:

```bash
docker compose ps
```

`database-empleados` debe aparecer como `healthy`. Compose espera ese estado antes de arrancar
`empleados-service` mediante `depends_on.condition: service_healthy`.

```text
API:          http://localhost:8080
Swagger UI:   http://localhost:8080/docs/
OpenAPI:      http://localhost:8080/openapi.json
PostgreSQL:   localhost:5433
```

## Persistencia y esquema

```bash
docker compose down
docker compose up -d
```

Los datos sobreviven porque permanecen en `employees-db-data`. Para borrarlos deliberadamente:

```bash
docker compose down -v
```

Se eligieron migraciones versionadas. `ms-employees` crea el schema, aplica cambios y registra las
versiones en `employees.schema_migrations` antes de aceptar tráfico. Esto permite evolucionar tablas
sin la limitación de `init.sql`, que solo se ejecuta cuando el volumen está vacío.

## Comandos útiles

```bash
docker compose up --build
docker compose down
docker compose logs -f empleados-service
docker compose logs -f database-empleados
```
