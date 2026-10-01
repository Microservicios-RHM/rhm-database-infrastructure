# Catálogo de eventos — Reto 4

> **Nota de procedencia.** El enunciado del Reto 4 referencia un "Catálogo de Eventos" externo
> (secciones 3.1 a 3.3) como fuente no negociable de nombres y payloads. Ese documento no estaba
> disponible en este repositorio ni fue provisto por el estudiante. Este archivo **es la definición
> canónica adoptada** para el ecosistema: los nombres de evento (`empleado.creado`,
> `empleado.actualizado`, `empleado.retirado`, `vacaciones.programadas`) y el envelope
> (`id`, `type`, `version`, `occurredAt`, `producer`, `data`) provienen literalmente del enunciado;
> los campos internos de `data` fueron diseñados a partir del modelo de `Employee` ya implementado en
> `ms-employees` y de los requisitos de cada servicio consumidor. Si en algún momento aparece el
> catálogo real del curso, este archivo debe actualizarse para igualarlo exactamente, y todos los
> productores/consumidores deben migrar en conjunto.

## Envelope común

Todo mensaje publicado en el broker respeta esta forma, sin excepción:

```json
{
  "id": "3f2a1c9e-7b4d-4e10-9c2a-1a2b3c4d5e6f",
  "type": "empleado.creado",
  "version": 1,
  "occurredAt": "2026-03-01T10:00:00.000Z",
  "producer": "empleados-service",
  "data": { }
}
```

| Campo | Tipo | Descripción |
|---|---|---|
| `id` | UUID v4 (string) | Identificador único del mensaje. Es la clave de deduplicación: dos entregas con el mismo `id` deben producir un único efecto observable en el consumidor. |
| `type` | string | Nombre del evento, tal como aparece en el catálogo (`dominio.evento`, snake libre en minúsculas con puntos). |
| `version` | integer | Versión del contrato de `data` para ese `type`. Empieza en `1`. Un cambio incompatible incrementa la versión, no reemplaza el campo. |
| `occurredAt` | datetime ISO 8601 (UTC) | Momento en que ocurrió el hecho de dominio (no el de publicación ni de entrega). |
| `producer` | string | Nombre del servicio que originó el evento (`empleados-service`, `vacaciones-service`). |
| `data` | object | Payload específico del evento. Ver secciones siguientes. |

## 1. `empleado.creado`

Publicado por `empleados-service` tras persistir exitosamente un alta (`POST /empleados`).

```json
{
  "id": "E001",
  "nombre": "Juan",
  "apellido": "Pérez",
  "email": "juan.perez@empresa.com",
  "numeroEmpleado": "EMP-2026-001",
  "cargo": "Desarrollador Senior",
  "area": "Tecnología",
  "departamentoId": "IT",
  "fechaIngreso": "2026-02-10",
  "estado": "ACTIVO",
  "fechaRetiro": null
}
```

Consumido por:
- `perfiles-service` → crea el perfil por defecto.
- `notificaciones-service` → registra la notificación `BIENVENIDA` y guarda `{id, nombre, apellido, email}` en su directorio local mínimo (ver justificación en el README de ese servicio).

## 2. `empleado.actualizado`

Publicado tras un `PUT /empleados/{id}` exitoso. `data` es el snapshot completo y actual del
empleado (mismo shape que `empleado.creado`), no un diff. Simplifica a los consumidores: siempre
reemplazan su copia local con el valor recibido.

```json
{
  "id": "E001",
  "nombre": "Juan",
  "apellido": "Pérez",
  "email": "juan.perez@empresa.com",
  "numeroEmpleado": "EMP-2026-001",
  "cargo": "Tech Lead",
  "area": "Tecnología",
  "departamentoId": "IT",
  "fechaIngreso": "2026-02-10",
  "estado": "ACTIVO",
  "fechaRetiro": null
}
```

Consumido por:
- `perfiles-service` → sincroniza los campos replicados (`nombre`, `email`) en el perfil existente.

`notificaciones-service` **no** consume este evento (no está en su lista de eventos requeridos por
el enunciado).

## 3. `empleado.retirado`

Publicado tras un `DELETE /empleados/{id}` exitoso (baja lógica: `estado = RETIRADO`,
`fechaRetiro` persistida). El empleado nunca se borra físicamente. Igual que
`empleado.actualizado`, `data` es el snapshot completo y actual del empleado, no solo los campos
que cambiaron.

```json
{
  "id": "E001",
  "nombre": "Juan",
  "apellido": "Pérez",
  "email": "juan.perez@empresa.com",
  "numeroEmpleado": "EMP-2026-001",
  "cargo": "Desarrollador Senior",
  "area": "Tecnología",
  "departamentoId": "IT",
  "fechaIngreso": "2026-02-10",
  "estado": "RETIRADO",
  "fechaRetiro": "2026-06-01T10:00:00.000Z"
}
```

Consumido por:
- `perfiles-service` → archiva el perfil (`archivado = true`), no lo borra.
- `notificaciones-service` → registra la notificación `DESVINCULACION`.

## 4. `vacaciones.programadas`

Publicado por `vacaciones-service` tras un `POST /vacaciones` exitoso. Solo anuncia que el período
quedó registrado; no desactiva ninguna cuenta (eso llega en el Reto 5 con `vacaciones.iniciadas`).

```json
{
  "id": "V-2026-0042",
  "empleadoId": "E001",
  "fechaInicio": "2026-03-15",
  "fechaFin": "2026-03-30",
  "estado": "PROGRAMADA",
  "fechaCreacion": "2026-03-01T10:00:00.000Z"
}
```

Consumido por:
- `notificaciones-service` → registra la notificación `VACACIONES`. Como este payload no trae
  `email`/`nombre`, el servicio resuelve el destinatario contra el directorio local que construyó a
  partir de `empleado.creado` (ver arriba). Si el `empleadoId` no está en el directorio, se registra
  un log de advertencia y no se genera notificación (no debería ocurrir en operación normal, porque
  `vacaciones-service` ya validó la existencia del empleado antes de publicar).

## Exchange y colas (RabbitMQ)

- Exchange tipo `topic`: `rhm.events`, durable.
- Cada evento se publica con `routing key = type` (p. ej. `empleado.creado`).
- Cada servicio consumidor declara su propia cola durable y la enlaza (`bind`) a los routing keys
  que le interesan — esto es lo que produce el **fan-out**: un mismo mensaje publicado una vez llega
  a todas las colas enlazadas.

| Cola | Bindings | Consumidor |
|---|---|---|
| `notificaciones.queue` | `empleado.creado`, `empleado.retirado`, `vacaciones.programadas` | `notificaciones-service` |
| `perfiles.queue` | `empleado.creado`, `empleado.actualizado`, `empleado.retirado` | `perfiles-service` |
| `vacaciones.queue` | `empleado.creado`, `empleado.retirado` | `vacaciones-service` (directorio local de empleados válidos) |

## Deduplicación

Todo consumidor debe, antes de aplicar el efecto de un mensaje:

1. Verificar si `id` ya existe en su tabla `eventos_procesados(id, procesado_en)`.
2. Si existe: hacer `ack` sin repetir el efecto.
3. Si no existe: aplicar el efecto y, en la misma transacción, insertar el `id` en
   `eventos_procesados`.

Esto es lo que se pide reproducir manualmente republicando el mismo mensaje desde la UI de RabbitMQ.
