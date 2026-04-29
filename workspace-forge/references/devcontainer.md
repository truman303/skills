# Devcontainer

This skill bundles a working devcontainer in `assets/devcontainer/` so a user
on Windows + Docker Desktop (the most common case where Nx + .NET native
tooling drift) can get an identical Linux environment with one VS Code action.

## When to use the bundled devcontainer

Use it when **any** of these is true:

- Host is Windows. Mixing the .NET 10 SDK and Node 24 native deps on Windows
  is doable but every cross-platform paper-cut (CRLF, `bin/`+`obj/` casing,
  npm bin shebangs, Playwright browsers) eats real time. Devcontainer skips
  the whole class.
- Host is macOS but the user wants CI parity (the bundled `ci.yml` runs on
  `ubuntu-latest`).
- The user explicitly asks for "reproducible env" / "same as CI".

Skip it when:

- Already inside a devcontainer (e.g. Codespaces). Detect via
  `[ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}" ] || [ -f /.dockerenv ]`.
- Host is Linux/macOS native and the user opted out.

## What's in the bundle

```
assets/devcontainer/
├── devcontainer.json     # template "C# (.NET) and PostgreSQL + Node.js"
├── docker-compose.yml    # two services: app, db (postgres:14.3)
└── Dockerfile            # base: mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble
```

Drop these as `.devcontainer/devcontainer.json`, `.devcontainer/docker-compose.yml`
and `.devcontainer/Dockerfile` at the workspace root. The names are baked in
(VS Code looks for `.devcontainer/devcontainer.json`).

### Notable settings, with rationale

- **Base image** `mcr.microsoft.com/devcontainers/dotnet:2-10.0-noble` ships
  the .NET 10 SDK. We layer Node 24 via the `ghcr.io/devcontainers/features/node:1`
  feature rather than rebuilding on a Node base — `dotnet` is the heavier
  install and we'd rather pull from Microsoft's prebuilt image.
- **Postgres sidecar.** The compose file declares a `db` service even though
  the demo doesn't talk to a database. It's there as headroom for a real app;
  removing it is a one-line edit to `docker-compose.yml` if the user objects.
  The `app` service runs `network_mode: service:db` so port 5432 is reachable
  on `localhost` from inside the container.
- **`forwardPorts: [4200, 5039]`** — Angular dev server and the .NET API.
  Keep these in sync if you change either app's listen port.
- **`CHOKIDAR_USEPOLLING=true`, `WATCHPACK_POLLING=true`.** File-watch on the
  Windows-host bind mount is unreliable without polling; this is the standard
  workaround for VS Code dev containers on WSL2 / Docker Desktop.
- **`workspaceFolder: /workspaces/${localWorkspaceFolderBasename}`** — keeps
  paths stable so absolute paths in `nx.json` cache keys / launchSettings
  don't change between host and container.

## Stop-and-resume protocol

After dropping the devcontainer files, the assistant **must halt** and tell
the user:

> The devcontainer config is staged. To continue, open this folder in VS Code
> and run **Dev Containers: Reopen in Container** (Ctrl/Cmd-Shift-P). Once the
> container is built and you're back at the prompt inside it, ping me and I'll
> resume from step 2.

Do not try to keep going on the host — `npm install`, `dotnet build`, and
`nx affected -t e2e` all behave subtly differently and the whole point of
the devcontainer is that the rest of the skill assumes a Linux environment.

## Variations the skill does **not** ship today

- A **rootless** devcontainer (the bundle uses the default `vscode` user
  inside the container, owned by the host UID via Docker Desktop). Fine for
  99% of cases.
- An **Nx Cloud agent** image — separate concern handled by `npx nx connect`
  later.
- A **GPU** profile. Out of scope for this skill.

If the user asks for any of these, point them at the upstream
[devcontainers/templates](https://github.com/devcontainers/templates) and let
them adapt the bundled compose file.
