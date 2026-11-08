# Observabilidad

Grafana se abre en `http://localhost:3000` con `admin/rhmUQ`.

En **Explore**, seleccionar Loki y consultar:

```logql
{job="docker"}
```

Para métricas seleccionar Prometheus y consultar, por ejemplo:

```promql
up
rate(http_requests_total[5m])
```

Jaeger se consulta en `http://localhost:16686`. El flujo esperado es Gateway →
servicio → base de datos/broker, con el mismo `traceId` en los spans.

