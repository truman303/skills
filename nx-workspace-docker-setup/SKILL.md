---
name: nx-workspace-docker-setup
description: Bootstrap a fresh Nx monorepo with Angular + .NET support inside a Docker dev container, including sample apps and Nx AI agent integration. Use this skill whenever the user wants to create a new Nx workspace in Docker, set up a containerized Nx monorepo, scaffold an Angular + dotnet polyglot workspace, "start a new nx project in docker", stand up a dev container for Nx, or mentions wanting Nx with both Angular and .NET/C# — even if they don't say "skill" or "Docker" explicitly. Trigger it when the conversation involves getting from an empty repo to a working `nx serve` + `nx build` for an Angular frontend alongside a .NET backend, all without requiring Node or the .NET SDK on the host.
---

# Nx Workspace Docker Setup

This skill walks a developer from an empty repo to a functioning Nx monorepo that can build and serve an Angular app, build/run a .NET webapi, and has the Nx AI agent integration wired up — all from inside a single Docker dev container that has both Node and the .NET SDK installed.

## Why this skill exists

Nx is excellent for polyglot monorepos, but the bootstrap experience has a bunch of papercuts the first time you do it:

- `create-nx-workspace` needs Node on the host by default.
- `@nx/dotnet` needs `dotnet` on `PATH` — so the dev container has to have both Node AND the .NET SDK.
- The Angular dev server won't be reachable from the host unless you pass `--host 0.0.0.0` AND disable inotify in favor of polling (WSL2/macOS bind mounts drop native filesystem events).
- The Dockerfile that works for day-to-day `nx serve` does NOT work for the initial `create-nx-workspace` step, because that step runs in an empty directory with no `package.json` to copy.
- Nx's AI agent integration (`nx configure-ai-agents`) is easy to forget and produces `CLAUDE.md` / `AGENTS.md` / MCP config that make every subsequent AI-assisted task dramatically better.

This skill encodes the right answers so the user gets a working workspace on the first try.

## Prerequisites (verify before starting)

- Docker and Docker Compose v2 installed on the host.
- An empty (or near-empty) repo where the new workspace should live. If the directory already contains a `package.json`, STOP and ask the user whether they want to create a new workspace (move/remove existing files) or add Nx to the existing project (different workflow — see https://nx.dev/docs/getting-started/start-with-existing-project).
- The user has decided on a workspace name (this becomes the npm scope, like `@acme/source`).

## High-level workflow

1. Copy the four Docker assets into the user's repo root.
2. Build the dev image (one-time, ~5–10 minutes because of the .NET SDK install).
3. Run `create-nx-workspace` inside an init container to scaffold the workspace.
4. Add `@nx/angular` and `@nx/dotnet` plugins.
5. Generate a sample Angular app and a sample .NET webapi.
6. Run `nx configure-ai-agents` to wire up AI agent support.
7. Update the compose files' `command:` lines to reference the real project names.
8. Verify with `nx serve <angular-app>` and `nx build <dotnet-api>`.

Explain each step to the user as you go — they're probably new to this stack and shouldn't just watch commands fly by.

## Step 1 — Copy Docker assets into the repo

Copy these four files from `assets/` in this skill directly into the user's repo root (do not nest them in a subdirectory — the `dockerfile:` and `context: .` paths in the compose files assume they're co-located with the source tree):

- `Dockerfile.dev` — Node 20 + .NET SDK 8, with `nx` installed globally.
- `docker-compose.dev.init.yml` — interactive container for running setup commands.
- `docker-compose.dev.build.yml` — one-shot `nx build` runner.
- `docker-compose.dev.serve.yml` — Angular dev server on port 4200.
- `.dockerignore` — keeps the build context small.

Each asset has comments at the top explaining what it does; preserve those comments when copying — they're part of the teaching value. You can use the Read tool to load them from `assets/` and then the Write tool to write them into the user's repo. Don't paraphrase or "improve" them silently; the user will read them.

## Step 2 — Build the dev image

```bash
docker compose -f docker-compose.dev.init.yml build
```

Warn the user this step installs the .NET SDK and takes several minutes the first time. Subsequent layer caching makes it fast.

## Step 3 — Scaffold the workspace with `create-nx-workspace`

Run the generator inside the init container, mounted against the empty repo. Use `--preset=angular-monorepo` so Nx sets up the Angular app structure correctly from the start; `--dotnet` is NOT a preset, so .NET is added as a plugin in the next step.

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx create-nx-workspace@latest . \
    --preset=angular-monorepo \
    --appName=<angular-app-name> \
    --style=scss \
    --packageManager=npm \
    --nxCloud=skip \
    --e2eTestRunner=none \
    --ci=skip
```

Substitute `<angular-app-name>` with whatever the user picked (e.g., `storefront`). The trailing `.` tells the generator to scaffold into the current (mounted) directory rather than create a child folder.

**Flag notes — read before adjusting:**

- `--preset=angular-monorepo` is the critical choice; `angular-standalone` produces a single-app layout that doesn't fit a polyglot monorepo.
- `--nxCloud=skip` avoids a signup prompt; the user can opt in later with `nx connect`.
- `--e2eTestRunner=none` skips Cypress/Playwright scaffolding. Add it back if the user asks.
- Leave `--packageManager=npm` unless the user has a strong preference; mixing pnpm/yarn with Docker mounts has subtle gotchas that'll derail the session.

If `create-nx-workspace` prompts interactively despite the flags (happens occasionally with new CLI versions), drop into a shell and run it manually:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init bash
# then inside the container:
npx create-nx-workspace@latest . --preset=angular-monorepo --appName=...
```

## Step 4 — Add the .NET plugin

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx add @nx/dotnet
```

`nx add` both installs the package AND registers the plugin in `nx.json` so inferred tasks start appearing. If the user did `npm install @nx/dotnet` instead, they'd have the package but no targets — `nx add` is the right path.

## Step 5 — Scaffold the sample .NET webapi

`@nx/dotnet` doesn't ship its own `dotnet new`-style generator; you use the actual `dotnet` CLI (which is why the Dockerfile installs the SDK). This is the official approach documented at https://nx.dev/docs/technologies/dotnet/introduction.

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  dotnet new webapi -o ./apps/<api-name>
```

After this runs, `@nx/dotnet`'s project inference will automatically detect the new `.csproj` and expose `build`, `run`, `test`, `publish`, etc. as Nx targets. Verify with:

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  nx show project <api-name>
```

You should see targets like `build`, `run`, `restore`.

## Step 6 — Configure Nx AI agents

This is the step most guides skip. It generates `CLAUDE.md`, `AGENTS.md`, and sets up the Nx MCP server so any AI assistant working in this repo gets workspace architecture context, access to generators, and CI integration.

```bash
docker compose -f docker-compose.dev.init.yml run --rm nx-init \
  npx nx configure-ai-agents
```

The command is interactive — it asks which agents to configure (Claude, Cursor, etc.). If the session is non-interactive and it hangs, drop into a shell (`docker compose ... run --rm nx-init bash`) and run it there. Reference: https://nx.dev/docs/features/enhance-ai.

After this completes, the workspace will contain at minimum:

- `CLAUDE.md` / `AGENTS.md` — workspace-specific agent guidelines.
- `.cursor/` or `.claude/` directories depending on chosen agents.
- Updated `.mcp.json` or similar with the Nx MCP server configured.

## Step 7 — Update compose `command:` lines

The shipped `docker-compose.dev.build.yml` and `docker-compose.dev.serve.yml` have placeholder `command: nx build my-app` / `command: nx serve my-app --host 0.0.0.0`. Edit these to reference the actual Angular app name the user chose in step 3. Example — if the app is `storefront`:

```yaml
# docker-compose.dev.serve.yml
command: nx serve storefront --host 0.0.0.0
```

```yaml
# docker-compose.dev.build.yml
command: nx build storefront
```

If the user also wants a shortcut for building the .NET api, duplicate `docker-compose.dev.build.yml` as `docker-compose.dev.build-api.yml` with `command: nx build <api-name>` — don't try to squeeze two services into one file; the user will get confused about which target is running.

## Step 8 — Verify the workspace works

Run these in separate terminals (or sequentially) and watch the output:

```bash
# Angular dev server — should print "Listening on 0.0.0.0:4200"
docker compose -f docker-compose.dev.serve.yml up

# In another terminal, build the Angular app end-to-end
docker compose -f docker-compose.dev.build.yml up --abort-on-container-exit

# Build the .NET api
docker compose -f docker-compose.dev.init.yml run --rm nx-init nx build <api-name>
```

Open http://localhost:4200 to confirm the Angular app renders.

Tell the user:

> You now have a polyglot Nx workspace with `<angular-app-name>` (Angular) and `<api-name>` (.NET webapi). Add more projects with `nx g @nx/angular:lib libs/<lib-name>` or `dotnet new classlib -o libs/<lib-name>`.

## Common failure modes and fixes

**`npm install` fails inside the container with `EACCES`.**
The host repo is owned by a different UID than the container's node user. Fix on the host: `sudo chown -R $USER:$USER .` (not inside the container). The existing README.md already warns about this.

**`nx serve` works inside the container but the app isn't reachable at `http://localhost:4200`.**
The command must include `--host 0.0.0.0` — `127.0.0.1` (the Angular default) only binds inside the container. Check the `command:` in `docker-compose.dev.serve.yml`.

**File changes on the host don't trigger a rebuild.**
`CHOKIDAR_USEPOLLING=true` must be set (it's in the compose files). If it's missing, Chokidar uses native inotify, which doesn't fire reliably across WSL2 or Docker Desktop's osxfs.

**`dotnet` command not found inside the container.**
The user probably modified `Dockerfile.dev` and removed the .NET SDK install block. Restore it from `assets/Dockerfile.dev` and rebuild with `docker compose build --no-cache`.

**`create-nx-workspace` fails with `EEXIST` / "directory is not empty".**
The target directory has files other than `.git`. Either move them aside or use a fresh directory. `create-nx-workspace` refuses to clobber existing content.

**`@nx/dotnet` plugin installs but no dotnet targets appear.**
Two likely causes: (1) there's no `.csproj` / `.fsproj` anywhere in the workspace yet — inference needs at least one project file; run `dotnet new webapi ...` first. (2) The plugin isn't listed in `nx.json`'s `plugins` array — run `nx add @nx/dotnet` (not `npm install`) to register it properly.

## Things to avoid

- Don't split the Node and .NET SDKs into separate containers. You can, but then `@nx/dotnet`'s inference — which runs in-process with Nx — won't see `dotnet` on PATH. Keep them combined.
- Don't run `create-nx-workspace` on the host "just this once" to get things moving. The whole point is the user doesn't need Node installed; breaking that promise in the first step teaches the wrong lesson.
- Don't add `npm install` or `COPY package.json` to `Dockerfile.dev`. It has to work BEFORE `package.json` exists (during the init step). The compose files mount the workspace and `npm install` happens as a side effect of `create-nx-workspace`.
- Don't skip `nx configure-ai-agents`. It's the difference between an AI agent that can navigate the workspace and one that grep-searches blindly. This is explicitly part of the user's goal for this skill.

## Reference files in this skill

- `assets/Dockerfile.dev` — the combined Node + .NET SDK image.
- `assets/docker-compose.dev.init.yml` — interactive one-off runner for setup commands.
- `assets/docker-compose.dev.build.yml` — one-shot `nx build` runner.
- `assets/docker-compose.dev.serve.yml` — Angular dev server on port 4200.
- `assets/.dockerignore` — keeps the build context small.

Read these files before writing them out so you can answer questions about the inline comments. Write them verbatim into the user's repo; the comments are load-bearing.
