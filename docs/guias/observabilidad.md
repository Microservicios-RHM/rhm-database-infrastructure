# Observabilidad

Grafana se abre en `http://localhost:3000`; Prometheus en `:9090`, Jaeger en `:16686`,
Alertmanager en `:9093` y MailHog en `:8025`.

Los siete servicios publican `rhm_http_requests_total`; los runtimes con histogramas publican
`rhm_http_request_duration_seconds` y los consumidores instrumentados publican
`rhm_events_total`. El dashboard **RHM Platform Overview** reúne disponibilidad, tráfico, 5xx,
eventos, colas, circuit breaker y logs.

Consultas PromQL operativas:

```promql
up
sum by (service) (rate(rhm_http_requests_total[5m]))
sum by (service) (rate(rhm_http_requests_total{status=~"5.."}[5m]))
sum by (service, outcome) (rate(rhm_events_total[5m]))
rhm_departments_circuit_breaker_open
rabbitmq_queue_messages_ready
```

Los logs de aplicación usan el contrato `timestamp`, `level`, `service`, `message`, `context`,
`traceId`; Promtail extrae `service`, `level` y `traceId`. Para seguir una operación entre Jaeger
y Loki, copie el identificador de traza y consulte en Grafana Explore:

```logql
{service_name=~".+-service|api-gateway", trace_id="<traceId>"}
```

OpenTelemetry exporta por OTLP/HTTP a Jaeger. El contexto W3C `traceparent` se propaga en HTTP y
en las cabeceras de RabbitMQ; los consumidores crean spans `CONSUMER`, por lo que un onboarding
se puede recorrer desde Gateway hasta los servicios asíncronos.

Las reglas cubren servicio caído, tasa de 5xx, latencia, fallos de eventos, apertura del circuit
breaker y acumulación de mensajes.
