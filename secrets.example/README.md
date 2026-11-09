# Secret templates

Run `bash scripts/setup-secrets.sh` from this directory root. It creates the ignored `secrets/`
directory with strong local values. Do not commit files created there.

The local platform accounts use `admin` / `rhmUQ` (RabbitMQ, the seed administrator, Grafana,
Jenkins and SonarQube). Database passwords are generated independently and are never reused as
platform credentials. Services consume passwords through `/run/secrets/*` and their `*_FILE`
variables; `.env` contains only non-sensitive configuration.

For an existing database volume, changing a secret does not change the account already persisted
inside PostgreSQL or MySQL. Rotate the database account with its native SQL command first, then
replace the matching secret and recreate the consuming service. Do not delete a volume merely to
change a credential.

To rotate a secret, stop the stack, replace the corresponding file under `secrets/`, and run
`docker compose up -d --force-recreate` for the services that consume it.
