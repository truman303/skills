# Docker setup (greenfield)

> `myapp` is the lowercase app name. Attach/hydra: skip this file. Use `deploy/compose/compose.dev.yml` or `compose.rig.yml`.

## `.env` (project root)

```
# Dev credentials. Do not commit.
POSTGRES_DB=myapp
POSTGRES_USER=myapp
POSTGRES_PASSWORD=<generate>
DEV_ADMIN_USERNAME=admin
DEV_ADMIN_PASSWORD=<generate>
DATABASE_URL=jdbc:postgresql://localhost:5432/myapp
DB_USER=myapp
DB_PASSWORD=<same as POSTGRES_PASSWORD>
UI_PORT=8080
```

Generate passwords. No `postgres`/`password` defaults in committed files.

## `docker-compose.yml`

```yaml
services:
  myapp-db:
    image: postgres:16-alpine
    container_name: myapp-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    ports:
      - "5432:5432"
    volumes:
      - ./db/data/postgresql:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U $${POSTGRES_USER} -d $${POSTGRES_DB}"]
      interval: 10s
      timeout: 5s
      retries: 5
```

`$$` becomes `$` inside the container.

Postgres 16 to match hydra's fast loop. Not 15. No reason to be older.

## `.gitignore`

```
.env
db/
```

## Startup script

Copy `${SKILL_DIR}/scripts/start-dev-environment.sh` into the project's `scripts/`. Substitute `MyApp` / `myapp-db`. It checks Docker, `docker compose up -d`, waits for healthy, exports env for the current shell if sourced.

```bash
./scripts/start-dev-environment.sh
./gradlew run
```

## Connection

`App` reads `DATABASE_URL`, `DB_USER`, `DB_PASSWORD`. The script can `set -a; source .env; set +a` before printing next steps so a subsequent `./gradlew run` in that terminal sees them. Also support loading `.env` inside `App` so an IDE run configuration works.
