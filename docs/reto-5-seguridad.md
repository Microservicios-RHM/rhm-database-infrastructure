# Seguridad y control de acceso (Reto 5)

Hasta el Reto 4 cualquiera que conociera `http://localhost:8080` podía crear o retirar empleados.
A partir de aquí toda petición necesita un token, y el ciclo de vida de la cuenta de cada empleado
lo gobiernan los eventos que ya circulaban por el broker.

## Estrategia de validación del token

Se eligió la **opción 1 del enunciado: validar en el API Gateway**, no con un interceptor por
servicio.

El ecosistema tiene seis servicios de negocio escritos en cinco lenguajes. Un interceptor por
servicio significaría resolver la verificación de firma cinco veces, con cinco librerías distintas,
y mantener sincronizadas cinco implementaciones de las mismas reglas de autorización. El Gateway ya
recibe todas las peticiones externas, así que la validación se escribe una sola vez.

El argumento se refuerza mirando hacia adelante: el Reto 10 traslada la validación a JWKS contra un
Identity Provider. Con la lógica en el Gateway eso es cambiar un archivo; repartida, serían seis.

Consecuencia que conviene tener presente: los microservicios de negocio **confían** en que lo que
les llega ya fue validado. Eso es aceptable porque ninguno publica puerto al host — solo se les
puede hablar desde dentro de la red de Docker, y la única puerta hacia afuera es el Gateway.

La excepción es `auth-service`, que valida el token por su cuenta en `POST /auth/change-password`:
necesita saber *quién* es el solicitante para cambiarle la contraseña, y además es el dueño del
secreto con el que se firma.

## El secreto JWT

La firma es simétrica (HMAC SHA-256). Tanto `auth-service`, que firma, como `api-gateway`, que
verifica, reciben el mismo valor por variable de entorno desde `docker-compose.yml`:

```dotenv
JWT_SECRET=change_this_jwt_secret
JWT_ISSUER=auth-service
JWT_ACCESS_TTL_SECONDS=3600
JWT_RESET_TTL_SECONDS=900
```

Si los dos valores difieren, ningún token emitido será aceptado. El secreto queda en claro en el
`.env.example` únicamente por tratarse de un entorno académico; en producción iría en un gestor de
secretos y la firma sería asimétrica, con la clave pública distribuida por JWKS.

No hay ningún secreto escrito en el código.

## Cómo obtener un token para probar

El sistema crea una cuenta administradora al arrancar, porque de otro modo nadie podría crear el
primer empleado: todos los endpoints de escritura exigen rol `ADMIN`.

```bash
curl -s -X POST http://localhost:8080/auth/login \
  -H "Content-Type: application/json" \
  -d '{"username":"admin","password":"change_admin_password"}'
```

```json
{
  "success": true,
  "message": "Autenticación exitosa",
  "data": {
    "accessToken": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
    "expiraEn": "2026-10-08T17:36:50.000Z"
  }
}
```

A partir de ahí, el token viaja en cada petición:

```bash
curl -s http://localhost:8080/empleados -H "Authorization: Bearer <accessToken>"
```

Desde **Swagger** es más cómodo: todas las UI están configuradas con el esquema `BearerAuth`, así
que basta pulsar **Authorize**, pegar el `accessToken` y probar los endpoints desde el navegador.
Las páginas de documentación quedan accesibles sin token a propósito — el enunciado pide poder
obtener el token desde ahí, y esas páginas no exponen datos del negocio.

La colección de Postman incluye el login como primera petición y guarda el token en una variable,
de modo que el resto de peticiones lo reutilizan automáticamente.

## Reglas de autorización

| Situación | Respuesta |
|---|---|
| Sin cabecera `Authorization`, o token con firma inválida o expirado | `401 Unauthorized` |
| Token de restablecimiento usado como token de acceso | `401 Unauthorized` |
| Rol `ADMIN` | Acceso total |
| Rol `USER`, método de lectura | Permitido |
| Rol `USER`, `POST /auth/change-password` | Permitido (su propia contraseña) |
| Rol `USER`, `PUT /perfiles/{id}` con `id == sub` | Permitido (su propio perfil) |
| Rol `USER`, cualquier otra escritura | `403 Forbidden` |

La última fila es lo que diferencia este reto de un RBAC clásico. Un `USER` no puede escribir en
general, pero sí sobre lo suyo, y eso no se decide mirando el rol sino **de quién es el recurso**:
se compara el `empleadoId` de la URL contra el claim `sub` del token. Es la diferencia entre RBAC y
ABAC, y es lo que permite que cada empleado administre su perfil sin darle permisos de
administrador.

Rutas abiertas sin token: `GET /health`, `POST /auth/login`, `POST /auth/recover-password`,
`POST /auth/reset-password` y las páginas de documentación de cada servicio.

## Ciclo de vida de la cuenta

El estado de la cuenta es un enum de cuatro valores, no un booleano. Esa decisión es la que hace
posible el caso borde: hay que poder distinguir una suspensión temporal de una baja definitiva.

```text
                 reset-password
PENDIENTE_ACTIVACION ──────────► ACTIVA ◄──────────┐
                                   │               │
                 vacaciones.iniciadas │            │ vacaciones.finalizadas
                                   ▼               │
                          SUSPENDIDA_TEMPORAL ─────┘
                                   │
                                   │ empleado.retirado
                                   ▼
                       DESACTIVADA_PERMANENTE  (estado terminal)
```

`DESACTIVADA_PERMANENTE` no tiene salida. Cuando llega un `vacaciones.finalizadas` sobre una cuenta
en ese estado, el evento se registra y se descarta sin reactivar nada.

### Diagrama de secuencia

```mermaid
sequenceDiagram
    actor Admin
    participant GW as api-gateway
    participant EMP as empleados-service
    participant BUS as message-broker
    participant AUTH as auth-service
    participant VAC as vacaciones-service
    participant NOT as notificaciones-service

    Admin->>GW: POST /empleados (Bearer ADMIN)
    GW->>EMP: valida el token y enruta
    EMP-->>BUS: empleado.creado
    BUS-->>AUTH: empleado.creado
    AUTH->>AUTH: crea la cuenta PENDIENTE_ACTIVACION, rol USER
    AUTH-->>BUS: usuario.creado (con token de activación)
    BUS-->>NOT: usuario.creado
    NOT->>NOT: registra notificación SEGURIDAD con el enlace

    Note over Admin,NOT: El empleado establece su contraseña
    Admin->>GW: POST /auth/reset-password (token + contraseña)
    GW->>AUTH: ruta abierta, sin token de acceso
    AUTH->>AUTH: hashea la contraseña, pasa a ACTIVA
    AUTH-->>BUS: cuenta.activada (ACTIVACION_INICIAL)
    BUS-->>NOT: cuenta.activada

    Note over Admin,NOT: Llega la fecha de inicio de sus vacaciones
    VAC->>VAC: el scheduler pasa el período a EN_CURSO
    VAC-->>BUS: vacaciones.iniciadas
    BUS-->>AUTH: vacaciones.iniciadas
    AUTH->>AUTH: pasa a SUSPENDIDA_TEMPORAL
    AUTH-->>BUS: cuenta.desactivada (VACACIONES, permanente=false)
    BUS-->>NOT: cuenta.desactivada
    Note over AUTH: POST /auth/login ahora responde 401

    Note over Admin,NOT: Termina el período
    VAC->>VAC: el scheduler pasa el período a FINALIZADA
    VAC-->>BUS: vacaciones.finalizadas
    BUS-->>AUTH: vacaciones.finalizadas
    AUTH->>AUTH: estaba SUSPENDIDA_TEMPORAL, vuelve a ACTIVA
    AUTH-->>BUS: cuenta.activada (FIN_VACACIONES)
    Note over AUTH: POST /auth/login vuelve a funcionar

    Note over Admin,NOT: Offboarding
    Admin->>GW: DELETE /empleados/{id} (Bearer ADMIN)
    GW->>EMP: valida el token y enruta
    EMP-->>BUS: empleado.retirado
    BUS-->>AUTH: empleado.retirado
    AUTH->>AUTH: pasa a DESACTIVADA_PERMANENTE
    AUTH-->>BUS: cuenta.desactivada (RETIRO, permanente=true)
    BUS-->>VAC: empleado.retirado
    VAC->>VAC: cancela los períodos PROGRAMADA; deja correr los EN_CURSO
```

## Scheduler de vacaciones

Hasta el Reto 4 un período quedaba `PROGRAMADA` para siempre, porque nada observaba el paso del
tiempo. `vacaciones-service` ahora ejecuta una tarea periódica que busca los períodos cuya fecha
llegó y los hace transicionar.

| Aspecto | Valor |
|---|---|
| Mecanismo | Hilo de Ruby con intervalo, sin gemas adicionales |
| Frecuencia | `VACATIONS_SCHEDULER_INTERVAL_SECONDS`, 60 segundos por defecto |
| Interruptor | `VACATIONS_SCHEDULER_ENABLED`, `true` por defecto |

Las transiciones se resuelven con un único `UPDATE ... RETURNING`, de modo que leer y cambiar el
estado es atómico: dos pasadas simultáneas no pueden publicar el mismo evento dos veces, porque la
segunda no encuentra filas que cumplan la condición.

### Cómo demostrarlo sin esperar un día

El enunciado sugiere programar vacaciones de hoy a hoy, pero eso **no funciona** aquí: la
validación de `POST /vacaciones`, que viene del Reto 4, exige que la fecha de fin sea posterior a
la de inicio. Esa regla es correcta y no se cambió.

En su lugar se expusieron dos endpoints de desarrollo, la tercera estrategia que propone el
enunciado. Disparan exactamente la misma transición y el mismo evento que dispararía el paso del
tiempo, y exigen rol `ADMIN`:

```bash
curl -s -X POST http://localhost:8080/vacaciones/V-2026-0001/forzar-inicio \
  -H "Authorization: Bearer <token ADMIN>"

curl -s -X POST http://localhost:8080/vacaciones/V-2026-0001/forzar-fin \
  -H "Authorization: Bearer <token ADMIN>"
```

No son atajos que salten reglas: si el período no está en el estado de origen correcto, responden
`409`.

### Limitación conocida

El hilo corre **dentro de cada instancia** del servicio. Con una sola instancia el comportamiento
es correcto, que es lo que este reto acepta.

Si `vacaciones-service` se escalara a N réplicas, las N ejecutarían el job y publicarían el mismo
evento N veces: N correos, N desactivaciones. Hay dos defensas y son complementarias:

1. **Deduplicación en el consumidor**, que ya existe desde el Reto 4: `auth-service` y
   `notificaciones-service` descartan el evento repetido por su `id` de envelope. Mitiga el daño,
   pero no evita el trabajo duplicado.
2. **Coordinación en el productor**: garantizar que solo una instancia ejecute el job. Es lo que
   resuelve el Reto 31 con un lock distribuido en base de datos (ShedLock).

El Reto 11 usará esta limitación como caso de estudio al escalar horizontalmente.

## Evidencia del caso borde

Si a un empleado lo retiran mientras está de vacaciones, al llegar la fecha de fin llega un
`vacaciones.finalizadas` sobre una cuenta que ya tiene baja permanente. **No debe reactivarse.**

Secuencia verificada:

```bash
# 1. Crear el empleado, establecer su contraseña y comprobar que puede entrar
#    POST /empleados -> 201   |   POST /auth/reset-password -> 200   |   POST /auth/login -> 200

# 2. Programar dos períodos: uno que inicia ya y otro futuro
#    POST /vacaciones -> V-2026-0003 (hoy → mañana)
#    POST /vacaciones -> V-2026-0004 (en dos días → en cinco)

# 3. Iniciar el primero
curl -s -X POST http://localhost:8080/vacaciones/V-2026-0003/forzar-inicio -H "Authorization: Bearer $ADMIN"

# 4. Retirar al empleado MIENTRAS está de vacaciones
curl -s -X DELETE http://localhost:8080/empleados/E200 -H "Authorization: Bearer $ADMIN"

# 5. El período futuro quedó cancelado; el que estaba en curso sigue corriendo
curl -s "http://localhost:8080/vacaciones?empleadoId=E200" -H "Authorization: Bearer $ADMIN"
# → V-2026-0004  CANCELADA
# → V-2026-0003  EN_CURSO

# 6. Terminar el período en curso
curl -s -X POST http://localhost:8080/vacaciones/V-2026-0003/forzar-fin -H "Authorization: Bearer $ADMIN"
```

En los logs de `auth-service`:

```json
{"empleadoId":"E200","estado":"DESACTIVADA_PERMANENTE",
 "msg":"Vacation ended but account is not temporarily suspended; reactivation skipped"}
```

Y el login sigue fallando:

```json
{"success":false,"message":"La cuenta está desactivada de forma permanente",
 "error":{"code":"ACCOUNT_DEACTIVATED","status":401}}
```

Que el período en curso se deje terminar en vez de cancelarlo no es un descuido: es lo que produce
el `vacaciones.finalizadas` que permite demostrar que la cuenta no se reactiva. Cancelarlo también
borraría la evidencia. Además, unas vacaciones que ya empezaron ocurrieron de verdad y no deberían
desaparecer del historial.
