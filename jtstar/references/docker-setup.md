# Docker setup (greenfield)

> `myapp` is the lowercase app name. When attaching to an existing app, skip this file and use the database that app already runs on.

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

If port 5432 is taken on the user's machine, change the host side of the mapping and the port in `DATABASE_URL` together.

## `.gitignore`

```
.env
db/
.gradle/
build/
tailwindcss
jte-classes/
```

`tailwindcss` is the Tailwind binary in the project root. `jte-classes/` is where JTE compiles templates when the app runs in dev.

## Startup script

Copy `${SKILL_DIR}/scripts/start-dev-environment.sh` into the project's `scripts/`. Substitute `MyApp` / `myapp-db`. It checks Docker, `docker compose up -d`, waits for healthy, exports env for the current shell if sourced.

```bash
./scripts/start-dev-environment.sh
./gradlew run
```

## Connection

`App` reads `DATABASE_URL`, `DB_USER`, `DB_PASSWORD`. The script can `set -a; source .env; set +a` before printing next steps so a subsequent `./gradlew run` in that terminal sees them. Also support loading `.env` inside `App` so an IDE run configuration works.
