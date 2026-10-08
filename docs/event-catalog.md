# Catálogo de eventos — Retos 4 y 5

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
>
> **Reto 5.** Los seis eventos de las secciones 5 a 10 siguen el mismo criterio: los nombres
> (`vacaciones.iniciadas`, `vacaciones.finalizadas`, `usuario.creado`, `usuario.recuperacion`,
> `cuenta.activada`, `cuenta.desactivada`) y los campos que el enunciado nombra explícitamente
> (`motivo`, `permanente`) se toman literalmente de él; el resto de `data` se diseñó para que cada
> consumidor pueda actuar sin consultar a nadie más.

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

## 5. `vacaciones.iniciadas`

Publicado por el scheduler de `vacaciones-service` cuando un período `PROGRAMADA` alcanza su
`fechaInicio` y transiciona a `EN_CURSO`. No lo dispara ninguna petición HTTP: lo dispara el paso
del tiempo.

```json
{
  "id": "V-2026-0042",
  "empleadoId": "E001",
  "fechaInicio": "2026-03-15",
  "fechaFin": "2026-03-30",
  "estado": "EN_CURSO"
}
```

Consumido por:
- `auth-service` → suspende la cuenta temporalmente (`SUSPENDIDA_TEMPORAL`) y publica
  `cuenta.desactivada`.

## 6. `vacaciones.finalizadas`

Publicado por el scheduler de `vacaciones-service` cuando un período `EN_CURSO` supera su
`fechaFin` y transiciona a `FINALIZADA`.

```json
{
  "id": "V-2026-0042",
  "empleadoId": "E001",
  "fechaInicio": "2026-03-15",
  "fechaFin": "2026-03-30",
  "estado": "FINALIZADA"
}
```

Consumido por:
- `auth-service` → reactiva la cuenta **solo si** está en `SUSPENDIDA_TEMPORAL`. Si el empleado fue
  retirado durante el período, la cuenta está en `DESACTIVADA_PERMANENTE` y el evento se descarta
  sin reactivar. Por eso el estado de la cuenta es un enum y no un booleano.

## 7. `usuario.creado`

Publicado por `auth-service` tras consumir `empleado.creado` y crear la cuenta en estado inactivo.
Lleva el token de activación porque sin él el correo de bienvenida no serviría de nada: es este
evento, y no `empleado.creado`, el que dispara ese correo.

```json
{
  "empleadoId": "E001",
  "email": "juan.perez@empresa.com",
  "rol": "USER",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiraEn": "2026-03-01T11:00:00.000Z"
}
```

Nunca viaja una contraseña, ni en claro ni hasheada.

Consumido por:
- `notificaciones-service` → registra la notificación `SEGURIDAD` con el enlace de activación.

## 8. `usuario.recuperacion`

Publicado por `auth-service` tras una petición a `POST /auth/recover-password`. Mismo payload que
`usuario.creado` salvo el rol, que aquí no aporta nada.

```json
{
  "empleadoId": "E001",
  "email": "juan.perez@empresa.com",
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiraEn": "2026-03-01T11:00:00.000Z"
}
```

Consumido por:
- `notificaciones-service` → registra la notificación `SEGURIDAD` con el enlace de restablecimiento.

## 9. `cuenta.activada`

Publicado por `auth-service` cuando una cuenta queda utilizable: al establecer la contraseña
inicial, o al reactivarse tras unas vacaciones.

```json
{
  "empleadoId": "E001",
  "email": "juan.perez@empresa.com",
  "motivo": "FIN_VACACIONES",
  "estado": "ACTIVA"
}
```

| `motivo` | Cuándo |
|---|---|
| `ACTIVACION_INICIAL` | El empleado estableció su contraseña con el token de activación. |
| `FIN_VACACIONES` | Consumo de `vacaciones.finalizadas` sobre una cuenta suspendida. |

Consumido por:
- `notificaciones-service` → registra la notificación `CUENTA`.

## 10. `cuenta.desactivada`

Publicado por `auth-service` cuando una cuenta deja de poder iniciar sesión. `permanente` distingue
las dos situaciones y es lo que permite al consumidor redactar el mensaje correcto.

```json
{
  "empleadoId": "E001",
  "email": "juan.perez@empresa.com",
  "motivo": "VACACIONES",
  "permanente": false,
  "estado": "SUSPENDIDA_TEMPORAL"
}
```

| `motivo` | `permanente` | `estado` resultante | Disparador |
|---|---|---|---|
| `VACACIONES` | `false` | `SUSPENDIDA_TEMPORAL` | Consumo de `vacaciones.iniciadas` |
| `RETIRO` | `true` | `DESACTIVADA_PERMANENTE` | Consumo de `empleado.retirado` |

Consumido por:
- `notificaciones-service` → registra la notificación `CUENTA`.

A diferencia de `vacaciones.programadas`, estos cuatro eventos sí incluyen `email`: `auth-service`
lo tiene de primera mano, porque es la credencial con la que el empleado inicia sesión.

## Exchange y colas (RabbitMQ)

- Exchange tipo `topic`: `rhm.events`, durable.
- Cada evento se publica con `routing key = type` (p. ej. `empleado.creado`).
- Cada servicio consumidor declara su propia cola durable y la enlaza (`bind`) a los routing keys
  que le interesan — esto es lo que produce el **fan-out**: un mismo mensaje publicado una vez llega
  a todas las colas enlazadas.

| Cola | Bindings | Consumidor |
|---|---|---|
| `notificaciones.queue` | `empleado.creado`, `empleado.retirado`, `vacaciones.programadas`, `usuario.creado`, `usuario.recuperacion`, `cuenta.activada`, `cuenta.desactivada` | `notificaciones-service` |
| `perfiles.queue` | `empleado.creado`, `empleado.actualizado`, `empleado.retirado` | `perfiles-service` |
| `vacaciones.queue` | `empleado.creado`, `empleado.retirado` | `vacaciones-service` (directorio local de empleados válidos) |
| `auth.queue` | `empleado.creado`, `empleado.retirado`, `vacaciones.iniciadas`, `vacaciones.finalizadas` | `auth-service` |

## Deduplicación

Todo consumidor debe, antes de aplicar el efecto de un mensaje:

1. Verificar si `id` ya existe en su tabla `eventos_procesados(id, procesado_en)`.
2. Si existe: hacer `ack` sin repetir el efecto.
3. Si no existe: aplicar el efecto y, en la misma transacción, insertar el `id` en
   `eventos_procesados`.

Esto es lo que se pide reproducir manualmente republicando el mismo mensaje desde la UI de RabbitMQ.
