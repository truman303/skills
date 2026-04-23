# Pollen — Nx + Angular + .NET in Docker

A step-by-step runbook to take your empty `~/code/pollen` repo to a working
Nx monorepo with:

- `pollen` — Angular frontend (`nx serve pollen` on http://localhost:4200)
- `pollen-api` — .NET 8 webapi (`nx build pollen-api`)
- Nx AI-agent integration wired up (Claude Code + friends)

All commands run **inside Docker** — you do not need Node or the .NET SDK on
your Mac.

---

## 0. Prerequisites

- Docker Desktop for Mac is installed and running (includes Docker Compose v2).
- `~/code/pollen` exists and is empty (except for your README).
- Your shell's working directory is `~/code/pollen` for every command below.

The four Docker files that this plan relies on are already in the repo root:

- `Dockerfile.dev` — Node 20 + .NET SDK 8, with global `nx`.
- `docker-compose.dev.init.yml` — interactive container for bootstrap/setup.
- `docker-compose.dev.build.yml` — one-shot `nx build pollen` (Angular).
- `docker-compose.dev.build-api.yml` — one-shot `nx build pollen-api` (.NET).
- `docker-compose.dev.serve.yml` — Angular dev server on port 4200.

Read the comments at the top of each file — they explain *why* each flag is
there (especially `--host 0.0.0.0` and `CHOKIDAR_USEPOLLING=true`).

---

## 1. Build the dev image (one time, ~5–10 min)

```bash
docker compose -f docker-compose.dev.init.yml build
```

This installs Node 20 + .NET SDK 8 + a global `nx`. It's slow the first time
because of the .NET SDK download; subsequent layer caching makes it fast.

---

## 2. Scaffold the Nx workspace (`create-nx-workspace`)

Run the generator inside the init container, writing into the mounted repo:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx create-nx-workspace@latest . \
    --preset=angular-monorepo \
    --appName=pollen \
    --style=scss \
    --packageManager=npm \
    --nxCloud=skip \
    --e2eTestRunner=none \
    --ci=skip
```

Key flags:

- `.` — scaffold *into* the current directory, not a child folder.
- `--preset=angular-monorepo` — gives a polyglot-friendly `apps/` + `libs/`
  layout. **Don't use `angular-standalone`** — it produces a single-app
  layout that doesn't fit a monorepo.
- `--appName=pollen` — your Angular app's name.
- `--nxCloud=skip` — no signup prompt; you can run `nx connect` later.
- `--e2eTestRunner=none` — skip Cypress/Playwright scaffolding.

If the generator still prompts interactively despite the flags, drop into
a shell and run it there:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init bash
# then, inside the container:
npx create-nx-workspace@latest . --preset=angular-monorepo --appName=pollen \
  --style=scss --packageManager=npm --nxCloud=skip --e2eTestRunner=none --ci=skip
```

---

## 3. Add the `@nx/dotnet` plugin

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx add @nx/dotnet
```

Use `nx add` (not `npm install`) — `nx add` both installs the package AND
registers it in `nx.json`'s `plugins` array so inferred targets start
appearing once a `.csproj` exists.

---

## 4. Scaffold the `pollen-api` .NET webapi

`@nx/dotnet` doesn't ship a generator — use the real `dotnet` CLI inside
the container (that's why the image has the SDK):

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  dotnet new webapi -o ./apps/pollen-api
```

Verify inference picked it up:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx show project pollen-api
```

You should see targets like `build`, `run`, `restore`, `publish`.

---

## 5. Wire up Nx's AI-agent integration (important for Claude Code)

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx nx configure-ai-agents
```

This is interactive — select Claude (and any others you use). It generates
`CLAUDE.md` / `AGENTS.md`, drops a `.claude/` (and/or `.cursor/`) config
directory, and configures the Nx MCP server so Claude Code can query your
workspace graph, run generators, and understand affected projects.

If the prompt hangs non-interactively, run it from a shell:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init bash
# inside:
npx nx configure-ai-agents
```

Reference: https://nx.dev/docs/features/enhance-ai

---

## 6. (Already done) Compose `command:` lines point at `pollen` / `pollen-api`

The `docker-compose.dev.serve.yml`, `docker-compose.dev.build.yml`, and
`docker-compose.dev.build-api.yml` files in this repo are already set to
`nx serve pollen --host 0.0.0.0`, `nx build pollen`, and `nx build
pollen-api` respectively. No edits needed.

---

## 7. Verify everything works

Angular dev server (leave running in one terminal):

```bash
docker compose -f docker-compose.dev.serve.yml up
```

Open http://localhost:4200 — you should see the Nx + Angular starter page
and file edits on the host should trigger reloads.

Build the Angular app end-to-end:

```bash
docker compose -f docker-compose.dev.build.yml up --abort-on-container-exit
```

Build the .NET api:

```bash
docker compose -f docker-compose.dev.build-api.yml up --abort-on-container-exit
```

Or, equivalently, via the init container:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init nx build pollen-api
```

---

## 8. Day-to-day from here

- Angular dev loop: `docker compose -f docker-compose.dev.serve.yml up`
- Build Angular: `docker compose -f docker-compose.dev.build.yml up --abort-on-container-exit`
- Build .NET api: `docker compose -f docker-compose.dev.build-api.yml up --abort-on-container-exit`
- Any other nx command: `docker compose -f docker-compose.dev.init.yml run --rm nx-init nx <whatever>`
- New Angular lib: `... nx-init nx g @nx/angular:lib libs/<lib-name>`
- New .NET class lib: `... nx-init dotnet new classlib -o libs/<lib-name>`

---

## Common gotchas

- **`npm install` fails with `EACCES`** — repo is owned by a different UID
  than the container's node user. On the host: `sudo chown -R $USER:$USER .`.
- **`http://localhost:4200` doesn't respond** — the `command:` must include
  `--host 0.0.0.0`. Default `127.0.0.1` only binds inside the container.
- **File changes don't trigger reloads** — `CHOKIDAR_USEPOLLING=true` must
  be set (it already is in the compose files). macOS bind mounts don't
  deliver inotify reliably.
- **`dotnet` not found in the container** — don't strip the .NET SDK block
  from `Dockerfile.dev`; rebuild with `docker compose build --no-cache`.
- **`@nx/dotnet` installed but no dotnet targets** — you need at least one
  `.csproj` in the workspace, and the plugin must be listed in `nx.json`'s
  `plugins` array. `nx add @nx/dotnet` handles the registration; running
  `dotnet new webapi` handles the csproj.
- **`create-nx-workspace` refuses with "directory is not empty"** — move
  any pre-existing files aside (the README is fine in most cases; if it
  complains, temporarily move it into `/tmp` and restore afterwards).
