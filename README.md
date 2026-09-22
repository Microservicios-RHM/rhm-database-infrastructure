# Plataforma RHM — infraestructura del Reto 2

Este repositorio contiene el único `docker-compose.yml` del sistema. Levanta los dos
microservicios y sus bases de datos aisladas con un solo comando.

| Componente | Tecnología | Puerto host | Volumen / dependencia |
|---|---|---:|---|
| `empleados-service` | Node.js + TypeScript | 8080 | `database-empleados` |
| `database-empleados` | PostgreSQL 17 | 5433, solo localhost | `employees-db-data` |
| `departamentos-service` | PHP 8.3 + Apache | 8081 | `database-departamentos` |
| `database-departamentos` | MySQL 8.4 | 3307, solo localhost | `departments-db-data` |

Dentro de Docker, empleados usa `database-empleados:5432` y departamentos usa
`database-departamentos:3306`. La validación del departamento se realiza por HTTP contra
`http://departamentos-service`; ningún servicio consulta la base de datos del otro.

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
Empleados:               http://localhost:8080
Swagger empleados:       http://localhost:8080/docs/
OpenAPI empleados:       http://localhost:8080/openapi.json

Departamentos:           http://localhost:8081
Swagger departamentos:   http://localhost:8081/docs/
OpenAPI departamentos:   http://localhost:8081/openapi.json
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

## Comandos útiles

```bash
docker compose logs -f empleados-service
docker compose logs -f departamentos-service
docker compose logs -f database-empleados
docker compose logs -f database-departamentos
```
