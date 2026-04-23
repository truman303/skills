# Pollen — Claude Code guide

Small CRM. Angular frontend + .NET 8 Web API backend in an Nx monorepo.
**Everything runs inside Docker** — the host has no Node or .NET SDK.

## Environment

- Repo lives at `~/code/pollen` on the host, bind-mounted at `/workspace/pollen`
  inside the `dev` container (see `docker-compose.yml`).
- `node_modules` and `.nx` cache live on named volumes for speed on macOS.
- The `dev` service needs to be up before any `nx` / `dotnet` command runs:
  `docker compose up -d dev`.

## Running commands

Never try to execute `nx`, `npm`, `node`, or `dotnet` directly on the host —
they aren't installed. Always go through the container:

```bash
docker compose exec dev <command>
# e.g.
docker compose exec dev npx nx graph
docker compose exec dev npx nx serve web --host 0.0.0.0
docker compose exec dev npx nx build api
docker compose exec dev npx nx test web
```

Interactive shell: `docker compose exec dev bash`.

## Project layout

- `apps/web`   — Angular app (`nx serve web`, port 4200)
- `apps/api`   — .NET Web API (`nx build api`, `nx serve api`, port 5000)
- `libs/`      — shared Nx libraries

## Nx AI integration

`.mcp.json` at the repo root wires Claude Code into the Nx MCP server.
When prompted about the project graph, generators, or running tasks, prefer
the `nx` MCP tools over ad-hoc shell calls — they are faster and understand
the workspace structure.
