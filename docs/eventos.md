# Catálogo de eventos

Todos los mensajes viajan por el exchange `rhm.events` y usan un envelope con `id`, `type`,
`version`, `occurredAt`, `producer` y `data`. Los consumidores guardan el `id` para ser idempotentes.
Las publicaciones incorporan `traceparent` para mantener la traza distribuida.

| Evento | Productor | Consumidores | Propósito |
|---|---|---|---|
| `empleado.creado` | empleados | auth, perfiles, vacaciones | Onboarding |
| `empleado.actualizado` | empleados | perfiles | Sincronización de perfil |
| `empleado.retirado` | empleados | auth, perfiles, vacaciones, notificaciones | Offboarding |
| `vacaciones.iniciadas` | vacaciones | auth, empleados, notificaciones | Suspensión temporal y estado del empleado |
| `vacaciones.finalizadas` | vacaciones | auth, empleados, notificaciones | Reactivación y estado del empleado |
| `usuario.creado` | auth | notificaciones | Correo de activación |
| `cuenta.activada` | auth | notificaciones | Confirmación de cuenta |
| `cuenta.desactivada` | auth | notificaciones | Aviso de desactivación |
