# Evidencia de cierre de seguridad — 2026-11-08

## Secretos y datos persistidos

- Se rotaron sin eliminar datos los roles PostgreSQL de Empleados, Notificaciones, Perfiles,
  Vacaciones, Auth y SonarQube.
- Se rotaron los usuarios MySQL de Departamentos.
- La cuenta ADMIN persistida fue reconciliada con `secrets/admin_password`.
- El stack completo fue recreado sobre los volúmenes existentes y todos sus healthchecks quedaron
  saludables usando secretos montados en `/run/secrets`.
- Jenkins lee las claves de administrador y E2E mediante su entrypoint de secretos.
- SonarQube, su base de datos y `sonar-init` leen sus claves desde Compose Secrets.

## Escaneo de secretos

Gitleaks `v8.24.0` terminó con código 0 sobre el historial completo de los nueve repositorios:

- `api-gateway`
- `auth-service`
- `e2e-tests`
- `ms-departments`
- `ms-employees`
- `ms-notifications`
- `ms-profiles`
- `ms-vacation`
- `rhm-database-infrastructure`

También terminaron con código 0 los escaneos `--no-git` específicos de `docker-compose.yml` y
`coleccion_postman/`. Las allowlists versionadas solo cubren ejemplos ficticios/truncados revisados;
las reglas predeterminadas continúan activas para cualquier hallazgo nuevo.

## Protección de logs y validación funcional

- Los errores de conexión AMQP ya no registran el error crudo de la librería, porque podría incluir
  la URI con usuario y contraseña.
- Una búsqueda exacta de `secrets/broker_url` sobre los logs completos del stack no encontró
  coincidencias.
- Los DSN PostgreSQL de Python, Go y Ruby codifican usuario/contraseña, permitiendo secretos
  aleatorios con caracteres reservados.
- Suite final: **31 escenarios exitosos, 222 pasos exitosos, 0 fallos y 0 errores**.

Keycloak/OIDC con JWKS permanece como mejora opcional y no bloqueante para el alcance académico.
