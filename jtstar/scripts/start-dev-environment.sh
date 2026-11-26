#!/usr/bin/env bash
# Copy into the project's scripts/ and replace MyApp / myapp-db.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f .env ]]; then
  echo "missing .env (POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, DEV_ADMIN_USERNAME, DEV_ADMIN_PASSWORD)" >&2
  exit 1
fi

required=(POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD DEV_ADMIN_USERNAME DEV_ADMIN_PASSWORD)
set -a
# shellcheck disable=SC1091
source .env
set +a

for key in "${required[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "missing $key in .env" >&2
    exit 1
  fi
done

if ! docker info >/dev/null 2>&1; then
  echo "Docker is not running" >&2
  exit 1
fi

if [[ "${1:-}" == "--force" ]]; then
  docker compose down -v
fi

docker compose up -d

echo "waiting for myapp-db..."
for i in $(seq 1 30); do
  status="$(docker inspect --format='{{.State.Health.Status}}' myapp-db 2>/dev/null || true)"
  if [[ "$status" == "healthy" ]]; then
    echo "MyApp database is healthy."
    echo "Next: ./gradlew run"
    echo "UI: http://localhost:${UI_PORT:-8080}"
    exit 0
  fi
  sleep 1
done

echo "myapp-db did not become healthy" >&2
docker compose ps
exit 1
