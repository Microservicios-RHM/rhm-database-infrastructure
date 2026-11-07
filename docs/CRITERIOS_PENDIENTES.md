# Criterios pendientes — proyecto final

> Revisión contrastada con `proyectoFinal.pdf`, el código de los nueve repositorios y la configuración real de `rhm-database-infrastructure` el 2026-11-07.
>
> Leyenda: ✅ cumplido y verificado · 🟡 parcial o sin evidencia E2E · ❌ pendiente.

## Estado ejecutivo

| Área | Estado | Situación real |
|---|---|---|
| Funcionalidad | 🟡 Avanzada | Los flujos y eventos principales existen; falta evidencia E2E completa. |
| Calidad técnica | 🟡 Parcial | Hay pruebas en seis servicios, pero no cobertura ≥70 % homogénea ni health de dependencias. |
| Observabilidad | 🟡 Base desplegada | Loki, Promtail, Prometheus, Grafana y Jaeger están en Compose; solo Gateway expone métricas. |
| Seguridad | 🟡 Parcial | Hay ejemplos y un secreto Compose para Grafana; las credenciales operativas siguen usando defaults. |
| Escalabilidad | ✅ Base implementada | Nginx, dos réplicas stateless, sin `container_name`, caché y circuit breaker activos. |
| DevOps | 🟡 Parcial | Jenkins, SonarQube y registry funcionan; pipelines completos solo para empleados y vacaciones. |
| Documentación | 🟡 Parcial | Infraestructura centralizada y documentos base; faltan guías, seeds y paquete final. |

## 1. Funcionalidad

### Cumplido

- ✅ Gateway, empleados, departamentos, autenticación, perfiles, vacaciones y notificaciones; más de cuatro lenguajes y BD por dominio.
- ✅ Onboarding, activación, login, recuperación/cambio de contraseña, RBAC y propiedad de perfiles.
- ✅ Offboarding lógico con `RETIRADO`, auditoría y archivado del perfil.
- ✅ RabbitMQ con envelopes y consumidores idempotentes.
- ✅ Vacaciones valida fechas/solapamientos y publica `vacaciones.iniciadas` y `vacaciones.finalizadas`.
- ✅ Empleados consume ambos eventos y sincroniza `ACTIVO` ↔ `EN_VACACIONES`, preservando `RETIRADO`.
- ✅ Plantilla HTML corporativa externa con Jinja2 y `NOTIFICATION_TEMPLATE_DIR`.
- ✅ Circuit breaker, reintentos, timeout y caché de departamentos; existe endpoint de limpieza.
- ✅ E2E definidos para humo, onboarding, vacaciones, offboarding y seguridad.

### Pendiente

- [ ] Ejecutar toda la suite E2E contra un stack recién levantado y guardar evidencia.
- [ ] Añadir E2E de perfiles: actualización propia y `403` sobre perfil ajeno.
- [ ] Probar de forma integrada la transición de estado causada por eventos de vacaciones.
- [ ] Opcional: `GET /empleados/{id}/completo` con degradación controlada si perfiles falla.

## 2. Calidad técnica y contratos

### Pruebas y cobertura

| Servicio | Pruebas | Umbral ≥70 % bloqueante |
|---|---|---|
| Gateway | ❌ no tiene script `test` | ❌ |
| Auth | ✅ `node:test` | ❌ solo reporta cobertura |
| Departamentos | ✅ PHPUnit configurado | ❌ sin umbral/evidencia CI |
| Empleados | ✅ unitarias e integración | ✅ `test:ci` exige líneas ≥70 % |
| Notificaciones | ✅ pytest | ❌ falta `pytest-cov --cov-fail-under=70` |
| Perfiles | ✅ `go test` | ❌ falta script que falle bajo 70 % |
| Vacaciones | ✅ RSpec | ✅ mínimo configurado |

### Health, OpenAPI y contenedores

- ✅ Swagger agregado en Gateway (`/swagger`) y contrato JSON en `/openapi.json`.
- ✅ Los servicios exponen documentación propia según su tecnología.
- ✅ Notificaciones usa multi-stage, usuario no root y plantilla externa.
- ❌ Los `/health` siguen siendo fijos: no comprueban BD/broker, no comparten `status/service/checks` ni devuelven `503` al caer una dependencia.
- ❌ Falta `openapi.yaml` versionado en la raíz de cada servicio y verificar respuestas 400/401/403/404/409/503.
- [ ] Verificar y endurecer ejecución sin root en departamentos.

## 3. Observabilidad

### Ya instalado

- ✅ Compose despliega Loki, Promtail, Prometheus, Grafana y Jaeger.
- ✅ Promtail lee logs de contenedores; Grafana tiene datasources, dashboard inicial y reglas Prometheus de caída/5xx.
- ✅ Gateway expone `/metrics` con métricas HTTP y de proceso.
- ✅ Nginx es el único punto público en `:8080`.

### Pendiente crítico

- [ ] `/metrics` reales en los otros seis servicios, más métricas de negocio, eventos y circuit breaker.
- [ ] Logs JSON homogéneos con `timestamp`, `level`, `service`, `message`, `context` y `traceId`.
- [ ] OpenTelemetry para HTTP, BD y AMQP en los siete servicios.
- [ ] Propagar/extraer `traceparent` por RabbitMQ y demostrar onboarding completo en Jaeger/Loki.
- [ ] Alertas entregables hacia MailHog u otro canal: servicio caído, 5xx, breaker abierto y cola acumulada.

## 4. Seguridad y configuración

### Ya implementado

- ✅ `.env` y `secrets/` están ignorados; existen `setup-secrets.sh` y `secrets.example/`.
- ✅ Grafana usa `grafana_admin_password` como Docker Compose Secret.
- ✅ BCrypt, RBAC y correos con token en lugar de contraseña.

### Pendiente crítico

- [ ] Migrar a Compose Secrets BD, RabbitMQ, JWT, ADMIN, Jenkins y SonarQube.
- [ ] Eliminar defaults secretos de Compose y exigir variables/secretos requeridos.
- [ ] Adaptar servicios a `/run/secrets/*` o variables `*_FILE`; hoy solo Grafana lo hace.
- [ ] Ejecutar Gitleaks sobre nueve historiales y colección Postman; conservar evidencia.
- [ ] Evitar que URL AMQP con contraseña llegue a logs.
- [ ] Opcional: Keycloak/OIDC con JWKS.

## 5. Escalabilidad y resiliencia

### Cumplido

- ✅ No hay `container_name`.
- ✅ Dos réplicas de Gateway, empleados, departamentos, auth y perfiles.
- ✅ Nginx balancea Gateway con timeouts/failover básicos.
- ✅ Vacaciones tiene una réplica; su scheduler no está preparado para concurrencia.

### Pendiente

- [ ] Documentar la única réplica de vacaciones e implementar lock de BD si se escala.
- [ ] Separar redes: edge, backend, messaging, data, observability y CI/CD; hoy hay una sola red.
- [ ] Guía/demo de caída de réplica y fallback/circuit breaker de departamentos.
- [ ] Documentar y probar timeouts/reintentos del Gateway.

## 6. DevOps

### Cumplido

- ✅ Jenkins JCasC, SonarQube, Quality Gate y registry se levantan desde Compose.
- ✅ Jenkins usa `:8090`; Prometheus conserva `:9090`.
- ✅ Jenkinsfile y Sonar configurados en empleados y vacaciones.

### Pendiente

- [ ] Jenkinsfile, Sonar y jobs para Gateway, Auth, Departamentos, Notificaciones y Perfiles.
- [ ] Homologar: checkout, lint, seguridad, test/cobertura, Sonar, Quality Gate, imagen, registry y E2E.
- [ ] Escaneo de dependencias/imágenes y lint por lenguaje.
- [ ] Webhook SCM o polling documentado.

## 7. Documentación y entrega

### Cumplido

- ✅ `rhm-database-infrastructure` es la fuente canónica de Compose, Nginx, observabilidad, scripts y documentación transversal.
- ✅ Existen README, `docs/arquitectura.md` y `docs/eventos.md`.
- ✅ Se validó un arranque limpio con `docker compose up --build -d --wait` desde infraestructura.

### Pendiente

- [ ] El PDF exige Compose en la raíz de la entrega. Preparar un directorio/ZIP que reúna los clones y tenga Compose en su raíz, sin crear otro repo Git ni duplicar código.
- [ ] `scripts/seed-data.sql` para departamentos/empleados y documentación de migraciones.
- [ ] `docs/guias/` para RabbitMQ, Jenkins, SonarQube, Grafana/Loki/Prometheus y Jaeger.
- [ ] Completar requisitos, URLs, curl de Gateway, decisiones y rotación de secretos.
- [ ] Generar ZIP sin `.env`, `secrets/`, dependencias, cachés ni artefactos.

## Prioridad de cierre

1. Health real 200/503, tests/cobertura ≥70 % y E2E ejecutados.
2. Secrets reales y Gitleaks.
3. Métricas, logs homogéneos, OpenTelemetry y propagación AMQP.
4. CI/Sonar para los cinco servicios restantes.
5. Redes, seeds, guías y paquete final.
