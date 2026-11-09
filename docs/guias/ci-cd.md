# CI/CD

Cada repositorio tiene un `Jenkinsfile` en la rama `chore/project-finalization`.
Las etapas son Checkout, Build, Test, Secret scan, Dependency scan, SonarQube,
Quality Gate, Package, Image scan y Publish. E2E es opcional mediante `RUN_E2E`
para no bloquear builds normales, pero se conserva para la evidencia de entrega.

Gitleaks bloquea secretos en el workspace. Trivy `0.76.2` archiva los hallazgos
HIGH/CRITICAL en `reports/security/dependencies.json` e `image.json`; el gate
falla ante un CRITICAL con corrección disponible. Los hallazgos todavía sin
parche permanecen visibles en el reporte y deben revisarse en cada actualización
de la base de vulnerabilidades. La caché persistente está aislada por servicio.

Cada pipeline tiene `pollSCM('H/5 * * * *')`, por lo que descubre cambios aun si
no hay webhook. En GitHub puede añadirse un webhook hacia
`http(s)://<jenkins>/github-webhook/`; el polling queda como respaldo operativo.
SonarQube usa el webhook interno `http://jenkins:8080/sonarqube-webhook/` para
desbloquear `waitForQualityGate`.

Una corrida manual se inicia desde **Build with Parameters**, seleccionando la
rama y `RUN_E2E`. La ejecución E2E crea un proyecto Compose aislado y siempre lo
elimina en las acciones posteriores del pipeline.

No se deben subir `.env`, `secrets/`, tokens ni credenciales. Jenkins y Sonar usan
credenciales gestionadas por JCasC.

