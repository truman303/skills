# Docker Setup Reference

> **Placeholder convention:** `myapp` (lowercase) is a placeholder throughout. Replace with the user's chosen app name (lowercase variant). See the Name Substitution table in [SKILL.md](../SKILL.md).

## docker-compose.yml

Create in the **solution root** (parent of the project folder):

```yaml
services:
  myapp-db:
    image: postgres:15-alpine
    container_name: myapp-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: myapp_dev_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - ./db/data/postgresql:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - myapp-network

networks:
  myapp-network:
    driver: bridge
```

## Placeholder Substitution

| Placeholder | Replace with | Example ("InventoryTracker") |
|---|---|---|
| `myapp-db` (service + container) | `{lowercase}-db` | `inventorytracker-db` |
| `POSTGRES_DB: myapp` | `{lowercase}` | `inventorytracker` |
| `POSTGRES_USER: myapp` | `{lowercase}` | `inventorytracker` |
| `POSTGRES_PASSWORD: myapp_dev_password` | `{lowercase}_dev_password` | `inventorytracker_dev_password` |
| `pg_isready -U myapp -d myapp` | Both values → `{lowercase}` | `pg_isready -U inventorytracker -d inventorytracker` |
| `myapp-network` | `{lowercase}-network` | `inventorytracker-network` |

## Start and Verify

```powershell
docker compose up -d
docker compose ps
```

The `STATUS` column should show `healthy` after ~15 seconds.

## .gitignore Entry

Add `db/` to `.gitignore` so local Postgres data volumes aren't committed:

```
# PostgreSQL local data
db/
```

## Matching Connection String (appsettings.json)

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=myapp;Username=myapp;Password=myapp_dev_password"
  }
}
```

Replace `myapp` / `myapp_dev_password` with the same values used in docker-compose.yml.
