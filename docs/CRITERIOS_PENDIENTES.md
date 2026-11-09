# Criterios pendientes — proyecto final

> Estado actualizado el 2026-11-09 contra `proyectoFinal.pdf`, los nueve repositorios, el stack local y las ejecuciones finales de Jenkins.
>
> Leyenda: ✅ cumplido y evidenciado · 🟡 implementado pero con validación pendiente o alcance parcial · ❌ pendiente.

## Estado ejecutivo

| Área | Estado | Situación real |
|---|---|---|
| Funcionalidad | ✅ Completa | Suite E2E: 31 escenarios, 31 exitosos, 0 fallos y 0 errores. |
| Calidad | ✅ Completa | Siete pipelines y Quality Gates verdes, cobertura ≥70 %, contratos versionados y contenedores sin root. |
| Seguridad | ✅ Completa | Secretos aplicados sobre datos persistidos y CI, Gitleaks limpio y credenciales AMQP protegidas en logs. |
| Observabilidad | ✅ Completa | Siete servicios con métricas y trazas, logs correlacionados, dashboard y seis alertas validadas. |
| Escalabilidad | ✅ Base implementada | Nginx, dos réplicas stateless, caché y circuit breaker. |
| DevOps | ✅ Completa | Las siete pipelines normales y las siete ejecuciones con E2E terminaron en `SUCCESS`; Quality Gate, Gitleaks, Trivy, registry y reportes operan. |
| Entrega | 🟡 Avanzada | Infraestructura, guías y validación limpia existen; faltan seeds y empaquetado ZIP final. |

## 1. Funcionalidad

### Cumplido y validado

- ✅ Gateway, Empleados, Departamentos, Auth, Perfiles, Vacaciones y Notificaciones; más de cuatro lenguajes y persistencia independiente por servicio.
- ✅ Onboarding: empleado, evento, cuenta, activación, contraseña, login y notificaciones.
- ✅ Seguridad: JWT, RBAC ADMIN/USER, token inválido/sin `Bearer` y token de activación rechazado como acceso.
- ✅ Perfiles: USER actualiza el propio perfil y recibe `403 FORBIDDEN` al modificar otro.
- ✅ Vacaciones: fechas, solapamientos, programación, notificación y transición `ACTIVO → EN_VACACIONES → ACTIVO` mediante eventos.
- ✅ Offboarding: retiro lógico, auditoría, notificación, bloqueo permanente y protección del retiro durante vacaciones.
- ✅ RabbitMQ con envelopes, consumidores idempotentes y eventos `vacaciones.iniciadas` / `vacaciones.finalizadas`.
- ✅ Plantillas HTML corporativas externas, caché, timeout, reintentos y circuit breaker de Departamentos.
- ✅ E2E repetido el **2026-11-08** sobre el stack persistido: **31 escenarios, 31 exitosos, 0 fallos y 222 pasos exitosos**.
- ✅ E2E repetido el **2026-11-09** en Jenkins sobre stacks efímeros y limpios, con Secrets aplicados: los siete jobs ejecutaron **31 escenarios y 222 pasos exitosos**.

### Pendiente funcional

- [x] Repetir los 31 E2E sobre un stack limpio con Secrets aplicados; validado en los siete jobs de Jenkins el 2026-11-09.
- [ ] Opcional y no bloqueante: `GET /empleados/{id}/completo` con degradación si Perfiles falla.

## 2. Calidad técnica y contratos

| Servicio | Estado de pruebas |
|---|---|
| API Gateway | ✅ `node:test`, Quality Gate OK; SonarQube 94.1 %. |
| Auth | ✅ `node:test`, Quality Gate OK; SonarQube 100 %. |
| Departamentos | ✅ PHPUnit, Quality Gate OK; SonarQube 100 %. |
| Empleados | ✅ Unitarias/integración, Quality Gate OK; SonarQube 90.9 %. |
| Notificaciones | ✅ Pytest, Quality Gate OK; SonarQube 73.7 %. |
| Perfiles | ✅ Go test, Quality Gate OK; SonarQube 83.1 %. |
| Vacaciones | ✅ RSpec/SimpleCov, Quality Gate OK; SonarQube 90.8 %. |

- ✅ Los siete `/health` usan `{status, service, checks}`, validan BD/broker cuando aplica y responden `503` ante dependencia crítica DOWN.
- ✅ Swagger agregado en Gateway y documentación propia por servicio.
- ✅ Los siete jobs de Jenkins tienen una última ejecución `SUCCESS` y los siete proyectos efectivos de SonarQube tienen Quality Gate `OK`.
- ✅ `openapi.yaml` versionado en la raíz de los siete servicios, con esquema uniforme y respuestas 400/401/403/404/409/503 donde aplican.
- ✅ Las siete imágenes declaran usuario no privilegiado; Departamentos se ejecuta como `www-data`.

Notas de alcance:

- Los porcentajes corresponden al alcance configurado por cada pipeline; no se presentan como cobertura global de toda la infraestructura.
- Incrementar cobertura adicional de reglas de negocio sigue siendo una mejora continua, no un criterio bloqueante porque los siete gates superan 70 %.

## 3. Observabilidad

Implementado:

- ✅ Compose despliega Loki, Promtail, Prometheus, Grafana y Jaeger.
- ✅ Gateway expone métricas HTTP/de proceso; Grafana tiene datasources y dashboard inicial.
- ✅ Jaeger recibe trazas de servicios Node, Python y Go instrumentados.
- ✅ Alertmanager recibe reglas de Prometheus y entrega correo a MailHog; se validó con una alerta sintética real.
- ✅ Prometheus recolecta los siete `/metrics` y RabbitMQ; los ocho targets estuvieron `UP` en la validación local.
- ✅ La configuración de Prometheus, Alertmanager y Promtail fue validada con sus binarios oficiales.

Completado y validado:

- ✅ Métricas reales y homogéneas en los siete: HTTP, errores, eventos, breaker y colas.
- ✅ Logs JSON homogéneos: `timestamp`, `level`, `service`, `message`, `context`, `traceId`.
- ✅ OpenTelemetry en PHP/Ruby y dependencias HTTP, BD y AMQP.
- ✅ `traceparent` propagado por RabbitMQ; los siete servicios aparecen en Jaeger y los `traceId` en Loki.
- ✅ Incidente controlado abrió `rhm_departments_circuit_breaker_open`; seis reglas de alerta validadas.
- ✅ Stack reconstruido con reloj UTC coherente; evidencia reciente en `docs/evidencias/observabilidad-2026-11-08.md`.

## 4. Seguridad y configuración

Implementado:

- ✅ `.env` y `secrets/` ignorados por Git.
- ✅ `setup-secrets.sh` crea secretos locales; BD con claves independientes.
- ✅ Los siete microservicios leen `/run/secrets/*` mediante `*_FILE`.
- ✅ Compose monta secretos de BD, RabbitMQ, JWT, administrador semilla y token de caché.
- ✅ Credenciales locales de plataforma: `admin / rhmUQ` para RabbitMQ, administrador semilla, Grafana, Jenkins y SonarQube; no se reutilizan en BD.
- ✅ La cuenta ADMIN de la base persistida fue reconciliada con `secrets/admin_password` y validada con los 31 E2E el 2026-11-08, sin eliminar datos.
- ✅ Roles de las seis bases PostgreSQL y usuarios MySQL de Departamentos rotados sin eliminar volúmenes; stack completo recreado y saludable.
- ✅ Jenkins, SonarQube, `sonar-init` y `sonar-db` consumen Compose Secrets sin contraseñas sensibles por defecto.
- ✅ Gitleaks limpio en los nueve historiales y en los escaneos explícitos de Compose/Postman; evidencia en `docs/evidencias/seguridad-2026-11-08.md`.
- ✅ Los errores AMQP se sanitizan y la URL completa del broker no aparece en los logs del stack.

Mejora opcional no bloqueante:

- [ ] Opcional: Keycloak/OIDC con JWKS.

## 5. Escalabilidad y resiliencia

- ✅ Sin `container_name`.
- ✅ Dos réplicas: Gateway, Empleados, Departamentos, Auth y Perfiles.
- ✅ Nginx único punto público en `:8080`, con balanceo y timeouts.
- ✅ Vacaciones en una réplica por su scheduler; requiere lock de BD/distribuido para escalar.
- ✅ Circuit breaker, caché y fallback de Departamentos.

Pendiente:

- [ ] Separar redes: edge, backend, messaging, data, observability y CI/CD.
- [ ] Guía/evidencia de caída de réplica y disponibilidad por Nginx.
- [ ] Guía/evidencia de fallback y circuit breaker.
- [ ] Documentar/probar timeout y reintentos del Gateway.

## 6. DevOps

- ✅ Jenkins JCasC, SonarQube, Quality Gate y registry local desde Compose.
- ✅ Jenkins `:8090`; Prometheus `:9090`.
- ✅ Los siete repositorios tienen `Jenkinsfile`; los jobs JCasC apuntan a la misma rama y ejecutan checkout, compilación/lint según lenguaje, pruebas, Gitleaks, SonarQube, Quality Gate, imagen y publicación en registry.
- ✅ Empleados y Vacaciones además publican reportes de cobertura y ejecutan la suite E2E aislada.
- ✅ Los stages E2E usan un bloqueo global (`rhm-e2e-stack`): las compilaciones pueden avanzar en paralelo, pero cada stack funcional se valida de forma aislada y sin depender del orden de los servicios.

Pendiente:

- ✅ Las siete pipelines publican JUnit/cobertura e incluyen una fase E2E aislada, opcional mediante `RUN_E2E`.
- [x] Ejecutar y conservar evidencia de una corrida normal y otra con `RUN_E2E` en Jenkins para cada variante de pipeline; detalle en `docs/evidencias/devops-e2e-2026-11-09.md`.
- ✅ Escaneo de dependencias e imágenes con Trivy además de Gitleaks; webhook de Sonar y polling SCM documentados.

## 7. Documentación y entrega

- ✅ `rhm-database-infrastructure` es la fuente canónica de Compose, Nginx, scripts y documentación transversal.
- ✅ README, arquitectura y catálogo de eventos disponibles.

Pendiente:

- [x] Validar arranque limpio con Secrets y repetir E2E; siete pipelines `SUCCESS` el 2026-11-09.
- [ ] Directorio/ZIP de entrega con Compose en su raíz, sin Git adicional ni duplicar código.
- [ ] `scripts/seed-data.sql` y guía de migraciones.
- ✅ Guías de arranque/validación, CI/CD, observabilidad y seguridad/rotación disponibles en `docs/guias/`.
- ✅ README y guías documentan requisitos, URLs, validaciones, decisiones, credenciales locales y rotación de secretos.
- [ ] ZIP sin `.env`, `secrets/`, dependencias, cachés ni artefactos.

## Prioridad de cierre

1. Redes y seeds.
2. Empaquetado final sin datos sensibles.
3. Mejoras opcionales no bloqueantes: endpoint agregado Empleados/Perfiles y Keycloak/OIDC.
