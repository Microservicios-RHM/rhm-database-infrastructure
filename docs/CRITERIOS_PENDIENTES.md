# Criterios pendientes — proyecto final

> Estado actualizado el 2026-11-07 contra `proyectoFinal.pdf`, los nueve repositorios y la ejecución real del stack local.
>
> Leyenda: ✅ cumplido y evidenciado · 🟡 implementado pero con validación pendiente o alcance parcial · ❌ pendiente.

## Estado ejecutivo

| Área | Estado | Situación real |
|---|---|---|
| Funcionalidad | ✅ Completa | Suite E2E: 31 escenarios, 31 exitosos, 0 fallos y 0 errores. |
| Calidad | 🟡 Avanzada | Health real en siete servicios y gates de cobertura; falta evidencia homogénea de CI. |
| Seguridad | 🟡 En migración | Los siete servicios soportan Compose Secrets; falta aplicarlos sobre BDs persistidas y herramientas CI. |
| Observabilidad | 🟡 Base desplegada | Grafana, Loki, Prometheus y Jaeger están arriba; faltan métricas, trazas y alertas homogéneas. |
| Escalabilidad | ✅ Base implementada | Nginx, dos réplicas stateless, caché y circuit breaker. |
| DevOps | 🟡 Parcial | Jenkins, SonarQube y registry operan; pipelines completos solo en Empleados y Vacaciones. |
| Entrega | 🟡 Parcial | Infraestructura y documentos base existen; faltan guías, seeds y ZIP final. |

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
- ✅ E2E ejecutado: **31 escenarios, 31 exitosos, 0 fallos, 0 errores**.

### Pendiente funcional

- [ ] Repetir los 31 E2E sobre un stack limpio con Secrets aplicados; es evidencia de configuración, no una brecha de negocio.
- [ ] Opcional y no bloqueante: `GET /empleados/{id}/completo` con degradación si Perfiles falla.

## 2. Calidad técnica y contratos

| Servicio | Estado de pruebas |
|---|---|
| API Gateway | ✅ `node:test`, gate ≥70 %; última medición crítica: 98.61 %. |
| Auth | ✅ `node:test`, gate ≥70 %; lógica crítica medida: 100 %. |
| Departamentos | ✅ PHPUnit y pruebas de reglas de aplicación. |
| Empleados | ✅ Unitarias/integración y `test:ci` ≥70 %. |
| Notificaciones | ✅ Pytest configurado con `pytest-cov --cov-fail-under=70`. |
| Perfiles | ✅ Go test, reporte y script que bloquea bajo 70 %. |
| Vacaciones | ✅ RSpec, SimpleCov y mínimo 70 %. |

- ✅ Los siete `/health` usan `{status, service, checks}`, validan BD/broker cuando aplica y responden `503` ante dependencia crítica DOWN.
- ✅ Swagger agregado en Gateway y documentación propia por servicio.

Pendiente:

- [ ] Ejecutar y conservar reportes de cobertura de los siete servicios desde CI reproducible.
- [ ] Incrementar la cobertura de reglas de negocio; no declarar 100 % global sin evidencia por servicio.
- [ ] Versionar `openapi.yaml` en la raíz de cada microservicio y completar respuestas 400/401/403/404/409/503.
- [ ] Verificar ejecución sin root en Departamentos.

## 3. Observabilidad

Implementado:

- ✅ Compose despliega Loki, Promtail, Prometheus, Grafana y Jaeger.
- ✅ Gateway expone métricas HTTP/de proceso; Grafana tiene datasources y dashboard inicial.
- ✅ Jaeger recibe trazas de servicios Node, Python y Go instrumentados.
- ✅ Alertmanager recibe reglas de Prometheus y entrega correo a MailHog; se validó con una alerta sintética real.
- ✅ Prometheus recolecta los siete `/metrics` y RabbitMQ; los ocho targets estuvieron `UP` en la validación local.
- ✅ La configuración de Prometheus, Alertmanager y Promtail fue validada con sus binarios oficiales.

Pendiente crítico:

- [ ] Métricas reales y homogéneas en los siete: HTTP, errores, eventos procesados/duplicados, breaker y negocio.
- [ ] Logs JSON homogéneos: `timestamp`, `level`, `service`, `message`, `context`, `traceId`.
- [ ] Completar OpenTelemetry en PHP/Ruby y dependencias HTTP, BD y AMQP.
- [ ] Propagar/extraer `traceparent` por RabbitMQ y demostrar onboarding en Jaeger y Loki.
- [ ] Reconstruir Empleados y demostrar con un incidente real la métrica `rhm_departments_circuit_breaker_open`; validar también las reglas de servicio caído, 5xx y cola acumulada.
- [ ] Corregir la desalineación de reloj de los contenedores ya existentes antes de declarar evidencia de logs recientes en Loki. Promtail ya descubre los contenedores y etiqueta sus logs.

## 4. Seguridad y configuración

Implementado:

- ✅ `.env` y `secrets/` ignorados por Git.
- ✅ `setup-secrets.sh` crea secretos locales; BD con claves independientes.
- ✅ Los siete microservicios leen `/run/secrets/*` mediante `*_FILE`.
- ✅ Compose monta secretos de BD, RabbitMQ, JWT, administrador semilla y token de caché.
- ✅ Credenciales locales de plataforma: `admin / rhmUQ` para RabbitMQ, administrador semilla, Grafana, Jenkins y SonarQube; no se reutilizan en BD.

Pendiente:

- [ ] Rotar usuarios de BD persistidos o levantar stack limpio antes de reiniciar con los nuevos secretos. No borrar volúmenes sin autorización.
- [ ] Conectar Jenkins y SonarQube a secretos de ejecución y eliminar defaults sensibles restantes.
- [ ] Ejecutar Gitleaks en nueve historiales, Compose y colección Postman; guardar evidencia.
- [ ] Evitar que la URL AMQP con credenciales llegue a logs.
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

Pendiente:

- [ ] Homologar los reportes JUnit/cobertura y una fase E2E aislada en Gateway, Auth, Departamentos, Notificaciones y Perfiles.
- [ ] Añadir escaneo de dependencias e imágenes además de Gitleaks, y documentar webhook/polling.

## 7. Documentación y entrega

- ✅ `rhm-database-infrastructure` es la fuente canónica de Compose, Nginx, scripts y documentación transversal.
- ✅ README, arquitectura y catálogo de eventos disponibles.

Pendiente:

- [ ] Validar arranque limpio con Secrets y repetir E2E.
- [ ] Directorio/ZIP de entrega con Compose en su raíz, sin Git adicional ni duplicar código.
- [ ] `scripts/seed-data.sql`, guía de migraciones y `docs/guias/` para RabbitMQ, Jenkins, Sonar, Grafana/Loki/Prometheus y Jaeger.
- [ ] Documentar requisitos, URLs, cURL, decisiones, credenciales locales y rotación de secretos.
- [ ] ZIP sin `.env`, `secrets/`, dependencias, cachés ni artefactos.

## Prioridad de cierre

1. Aplicar/validar Secrets sobre stack limpio, repetir E2E y ejecutar Gitleaks.
2. Cerrar métricas, logs, trazabilidad AMQP y alertas.
3. Pipelines/Jenkins/Sonar de los cinco servicios faltantes.
4. Redes, seeds y guías.
5. Empaquetado final sin datos sensibles.
