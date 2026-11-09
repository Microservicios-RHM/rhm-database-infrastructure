# Secretos y rotación

Los secretos locales se generan con `scripts/setup-secrets.sh` y se montan en
`/run/secrets`. La carpeta `secrets/` está excluida de Git.

Para rotar un secreto:

1. Detener el servicio afectado.
2. Cambiar el archivo local correspondiente.
3. Recrear únicamente el servicio: `docker compose up -d --force-recreate <servicio>`.
4. Validar `/health`, autenticación y publicación/consumo de eventos.

Las contraseñas de bases de datos persistidas no se cambian automáticamente: deben
rotarse mediante el procedimiento del motor y una ventana controlada.

