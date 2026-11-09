# Evidencia de observabilidad — 2026-11-08

## Resultado

- Los ocho targets operativos de Prometheus (`api-gateway`, seis servicios, Vacaciones y
  RabbitMQ) respondieron `UP`.
- `rhm_http_requests_total` devolvió las siete etiquetas `service` esperadas.
- Jaeger registró los siete servicios: Gateway, Auth, Departamentos, Empleados, Notificaciones,
  Perfiles y Vacaciones.
- Loki expuso 557 valores de `trace_id` después de la suite integral.
- La suite final terminó con 31 escenarios y 222 pasos exitosos.
- Prometheus validó la configuración y seis reglas; Alertmanager validó su configuración.

## Incidentes controlados

La primera ejecución descubrió una incompatibilidad real de contexto en el consumidor Ruby.
`EventProcessingFailures` entró en estado `firing`, el log correlacionado señaló
`unknown keyword: :with_parent` y se corrigió usando `OpenTelemetry::Context.with_current`.
La repetición completa quedó verde.

Para probar resiliencia se detuvieron temporalmente las dos réplicas de Departamentos y se
hicieron ocho validaciones desde una réplica de Empleados. Las ocho respondieron `503` y
`rhm_departments_circuit_breaker_open` cambió a `1`. Departamentos fue restaurado y sus dos
réplicas regresaron a estado saludable.

## Cobertura implementada

- Métricas HTTP homogéneas, duración, eventos, errores, circuit breaker y colas.
- Logs JSON con `timestamp`, `level`, `service`, `message`, `context` y `traceId`.
- OpenTelemetry OTLP en Node, Python, Go, PHP y Ruby.
- Propagación W3C por HTTP y cabeceras RabbitMQ; spans `PRODUCER`/`CONSUMER` donde aplica.
- Dashboard Grafana para disponibilidad, tráfico, 5xx, eventos, colas, breaker y logs.
- Alertas de caída, 5xx, latencia, fallos de eventos, breaker abierto y backlog de RabbitMQ.
