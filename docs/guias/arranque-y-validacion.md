# Arranque y validación

Desde este repositorio:

```bash
./scripts/setup-secrets.sh
docker compose up --build -d --wait
```

URLs locales: Gateway `http://localhost:8080`, Jenkins `:8090`, SonarQube `:9000`,
Grafana `:3000`, Prometheus `:9090`, Jaeger `:16686`, RabbitMQ `:15672` y MailHog `:8025`.

En Jenkins, `RUN_E2E=false` ejecuta el pipeline normal. Para la validación integral,
usar **Build with Parameters** y activar `RUN_E2E`.

Validaciones rápidas:

```bash
curl http://localhost:8080/health
curl http://localhost:8080/metrics
docker compose ps
```

