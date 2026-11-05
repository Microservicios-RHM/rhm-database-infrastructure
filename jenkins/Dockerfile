# Jenkins del ecosistema RHM: plugins, cliente Docker y configuración (JCasC) incluidos en la imagen,
# de modo que `docker compose up --build` deja Jenkins listo sin pasos manuales en la interfaz.
FROM jenkins/jenkins:lts-jdk21

# Plugins preinstalados. Referencia: https://github.com/jenkinsci/docker#preinstalling-plugins
COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt
RUN jenkins-plugin-cli --plugin-file /usr/share/jenkins/ref/plugins.txt

USER root

# Cliente Docker + plugins compose y buildx, copiados de la imagen oficial `docker:cli` (binarios
# estáticos). Se evita `apt-get install docker.io`, que además del cliente instala un daemon que
# aquí no se usa (se habla con el Docker del host por el socket montado) y no trae `docker compose`.
COPY --from=docker:29-cli /usr/local/bin/docker /usr/local/bin/docker
COPY --from=docker:29-cli /usr/local/libexec/docker/cli-plugins /usr/local/libexec/docker/cli-plugins

# Configuración como código: usuario administrador, credenciales, servidor SonarQube y jobs.
# Vive fuera de JENKINS_HOME para que un rebuild de la imagen la actualice aunque el volumen persista.
COPY casc.yaml /usr/share/jenkins/casc/jenkins.yaml
ENV CASC_JENKINS_CONFIG=/usr/share/jenkins/casc/jenkins.yaml

# Jenkins corre siempre como el usuario sin privilegios `jenkins` (uid 1000). El acceso al socket
# Docker del host no requiere root: docker-compose.yml agrega el GID del socket con `group_add`
# (variable DOCKER_GID del .env, que cambia entre máquinas).
USER jenkins
