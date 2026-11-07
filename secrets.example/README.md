# Secret templates

Run `bash scripts/setup-secrets.sh` from this directory root. It creates the ignored `secrets/`
directory with strong local values. Do not commit files created there.

To rotate a secret, stop the stack, replace the corresponding file under `secrets/`, and run
`docker compose up -d --force-recreate` for the services that consume it.
