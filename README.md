# Infraestructura de base de datos RHM

Infraestructura local de PostgreSQL compartida por los microservicios del sistema RHM. Se utiliza
una sola instancia y una sola base de datos, con un schema y credenciales independientes para cada
microservicio.

## Diseño actual

```text
PostgreSQL 17
└── base rhm
    └── schema employees
        └── propietario employees_service
```

El usuario de `ms-employees` no es administrador de PostgreSQL y su `search_path` apunta al schema
`employees`. Los nuevos microservicios deberán incorporar su propio usuario y schema siguiendo el
mismo patrón.

## Inicio local

Crear el archivo local de variables a partir del ejemplo:

```bash
cp .env.example .env
```

Cambiar las contraseñas de ejemplo y levantar PostgreSQL:

```bash
docker compose up -d
docker compose ps
```

Detenerlo sin eliminar los datos:

```bash
docker compose down
```

La información se conserva en el volumen `rhm-postgres-data`.

## Conexión de ms-employees

Cuando el microservicio se ejecute directamente en la máquina:

```env
DB_HOST=localhost
DB_PORT=5432
DB_NAME=rhm
DB_SCHEMA=employees
DB_USER=employees_service
DB_PASSWORD=la_misma_clave_de_EMPLOYEES_DB_PASSWORD
```

Cuando `ms-employees` se ejecute en otro contenedor conectado a `rhm-network`:

```env
DB_HOST=postgres
DB_PORT=5432
DB_NAME=rhm
DB_SCHEMA=employees
DB_USER=employees_service
DB_PASSWORD=la_misma_clave_de_EMPLOYEES_DB_PASSWORD
```

Dentro de contenedores se utiliza el nombre del servicio `postgres`, no `localhost`.

## Inicialización

Los archivos de `database/init` solo se ejecutan cuando PostgreSQL crea un volumen vacío. Modificar
un archivo de inicialización no altera un volumen ya creado. Los cambios posteriores del esquema de
tablas deben gestionarse mediante las migraciones propias de cada microservicio.

No ejecutar `docker compose down -v` salvo que se quiera borrar definitivamente la base local y
volver a ejecutar toda la inicialización.

## Responsabilidades

Este repositorio administra:

- La instancia PostgreSQL compartida.
- La base de datos `rhm`.
- La red y el volumen de Docker.
- Los usuarios y schemas de cada microservicio.

Cada microservicio administra sus tablas, índices y migraciones, y nunca consulta directamente los
schemas pertenecientes a otros servicios.
