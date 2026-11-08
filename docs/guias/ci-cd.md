# CI/CD

Cada repositorio tiene un `Jenkinsfile` en la rama `chore/project-finalization`.
Las etapas son Checkout, Build, Test, Secret Scan, SonarQube, Quality Gate,
Package y Publish. E2E es opcional mediante `RUN_E2E` para no bloquear builds
normales, pero se conserva para la evidencia de entrega.

No se deben subir `.env`, `secrets/`, tokens ni credenciales. Jenkins y Sonar usan
credenciales gestionadas por JCasC.

