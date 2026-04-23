# Nx Monorepo (Angular + .NET) in Docker — Setup Plan

## Assumptions

The user's prompt was terse, so defaults were chosen:

- **Angular app name:** `web`
- **.NET webapi name:** `api`
- **Workspace scope:** left to the `create-nx-workspace` default (can be overridden interactively or with `--workspaceName`).
- **Node:** 20 (LTS, in the dev image).
- **.NET SDK:** 8 (LTS, in the dev image).
- **Package manager:** npm.

If these defaults don't fit, substitute names everywhere `web` / `api` appear below and update `command:` lines in `docker-compose.dev.serve.yml` / `docker-compose.dev.build.yml`.

## Files written to the repo root

- `Dockerfile.dev` — Node 20 + .NET SDK 8 dev image with `nx` installed globally.
- `docker-compose.dev.init.yml` — interactive container for scaffolding commands.
- `docker-compose.dev.build.yml` — one-shot `nx build web` runner.
- `docker-compose.dev.serve.yml` — Angular dev server on port 4200 (`nx serve web --host 0.0.0.0`).

The `command:` lines in the build and serve compose files have been pre-filled with `web` (the chosen Angular app name). Edit them if you pick different names.

Note: the skill also references a `.dockerignore` but no such asset ships with the skill; not writing one keeps us faithful to the "do not paraphrase or improve silently" rule. Add one later if the build context grows.

## Commands to run, in order

All commands run from the repo root. None of them require Node or .NET on the host — everything runs inside the dev container.

### 1. Build the dev image (one-time, ~5–10 minutes)

```bash
docker compose -f docker-compose.dev.init.yml build
```

Installs the .NET SDK on top of the Node 20 base. Slow first time; cached afterwards.

### 2. Scaffold the Nx workspace

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx create-nx-workspace@latest . \
    --preset=angular-monorepo \
    --appName=web \
    --style=scss \
    --packageManager=npm \
    --nxCloud=skip \
    --e2eTestRunner=none \
    --ci=skip
```

The trailing `.` scaffolds into the mounted repo (not a child folder). `--preset=angular-monorepo` is the right choice for a polyglot monorepo; `angular-standalone` would produce a single-app layout.

If the generator prompts interactively despite the flags:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init bash
# then in the container:
npx create-nx-workspace@latest . --preset=angular-monorepo --appName=web
```

### 3. Add the .NET plugin

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx add @nx/dotnet
```

Use `nx add` (not `npm install`) so the plugin is registered in `nx.json` and inferred targets appear.

### 4. Scaffold the sample .NET webapi

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  dotnet new webapi -o ./apps/api
```

`@nx/dotnet` infers targets from the new `.csproj`. Verify with:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx show project api
```

You should see `build`, `run`, `restore`, etc.

### 5. Configure Nx AI agents

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx nx configure-ai-agents
```

Interactive — choose which agents (Claude, Cursor, …) you want. Produces `CLAUDE.md` / `AGENTS.md` and wires up the Nx MCP server so future AI assistance has workspace context. If it hangs non-interactively, drop into a shell and run it there.

### 6. (Already done in the files above) Update compose `command:` lines

`docker-compose.dev.serve.yml` → `command: nx serve web --host 0.0.0.0`
`docker-compose.dev.build.yml` → `command: nx build web`

If you also want a build shortcut for the .NET api, copy the build compose file to `docker-compose.dev.build-api.yml` and change its `command:` to `nx build api`.

### 7. Verify the workspace

```bash
# Angular dev server — expect "Listening on 0.0.0.0:4200"
docker compose -f docker-compose.dev.serve.yml up

# In another terminal, build the Angular app
docker compose -f docker-compose.dev.build.yml up --abort-on-container-exit

# Build the .NET api
docker compose -f docker-compose.dev.init.yml run --rm nx-init nx build api
```

Open <http://localhost:4200> — the starter Angular app should render.

## Extending the workspace

- New Angular lib: `nx g @nx/angular:lib libs/<lib-name>`
- New .NET classlib: `dotnet new classlib -o libs/<lib-name>`

## Common pitfalls

- **Host can't reach `localhost:4200`:** serve command is missing `--host 0.0.0.0`.
- **File edits don't trigger rebuilds:** `CHOKIDAR_USEPOLLING=true` missing from the compose env (it's in the shipped files).
- **`EACCES` on `npm install`:** host uid ≠ container uid; fix on the host with `sudo chown -R $USER:$USER .`.
- **`dotnet: command not found` in container:** `Dockerfile.dev` was modified and the SDK install block removed — restore from the skill's `assets/Dockerfile.dev` and rebuild with `--no-cache`.
- **No dotnet targets after `nx add @nx/dotnet`:** no `.csproj` exists yet — run `dotnet new webapi -o ./apps/api` first. Inference needs a project file.
- **`create-nx-workspace` refuses to run (EEXIST):** the target dir has files other than `.git`. Move them aside or start fresh.
