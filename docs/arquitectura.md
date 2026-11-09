# Arquitectura

```mermaid
flowchart LR
  Client --> Edge[Nginx :8080]
  Edge --> Gateway1[API Gateway x2]
  Gateway1 --> Employees[Empleados x2]
  Gateway1 --> Departments[Departamentos x2]
  Gateway1 --> Auth[Auth x2]
  Gateway1 --> Profiles[Perfiles x2]
  Gateway1 --> Vacations[Vacaciones]
  Employees --> Broker[(RabbitMQ)]
  Broker --> Auth
  Broker --> Profiles
  Broker --> Vacations
  Broker --> Notifications[Notificaciones]
  Services[Servicios] --> Prometheus
  Services --> Loki
  Services --> Jaeger
  Prometheus --> Grafana
  Loki --> Grafana
  Jaeger --> Grafana
```

Los servicios son dueños de su base de datos. RabbitMQ distribuye eventos de dominio; ningún
servicio consulta directamente la base de datos de otro servicio. Nginx balancea el Gateway y el
DNS interno de Docker balancea las réplicas de servicios stateless.

Vacaciones se conserva en una sola réplica porque ejecuta un scheduler. Antes de escalarlo se debe
usar un lock distribuido/advisory lock para impedir publicaciones duplicadas.
