# Plan: Nx monorepo with Angular + C# (.NET) in Docker

## Assumptions

- Angular app is called **`web`**, .NET 8 Web API is called **`api`**.
- Nx workspace lives at the repo root (the sandbox dir) with `apps/web` and `apps/api`.
- You want everything to run inside Docker, so neither Node.js nor the .NET SDK need to be installed on the host.
- We use the community-maintained [`@nx-dotnet/core`](https://www.nx-dotnet.com/) plugin to make Nx aware of the .NET project (build/serve/test/lint targets wired to `dotnet`).

## Files written to the sandbox

| File | Purpose |
|---|---|
| `Dockerfile` | Dev image based on `mcr.microsoft.com/dotnet/sdk:8.0` with Node 20 + Nx installed. |
| `docker-compose.yml` | `dev` (interactive shell), `web` (Angular), `api` (.NET) services; mounts the repo into `/workspace`. |
| `.dockerignore` | Keeps `node_modules`, `bin`, `obj`, `.nx/cache`, etc. out of the build context. |
| `.devcontainer/devcontainer.json` | Optional — lets VS Code "Reopen in Container" into the same image. |
| `README.md` | Short developer-facing overview. |

## Commands to run, in order

All `nx`/`dotnet`/`npm` commands are run **inside the dev container**, never on the host.

### 1. Build the dev image

```bash
docker compose build dev
```

### 2. Open a shell inside the container

```bash
docker compose run --rm --service-ports dev
# you are now at root@<id>:/workspace#
```

From here on, every command is run inside that container shell.

### 3. Generate the Nx workspace in place

The sandbox directory is already the repo root and is mounted at `/workspace`. Create an empty Nx workspace in it:

```bash
npx --yes create-nx-workspace@latest . \
  --preset=apps \
  --packageManager=npm \
  --nxCloud=skip
```

`--preset=apps` gives you an empty workspace with an `apps/` folder and no default app, which is what we want since we'll add both `web` and `api` ourselves.

### 4. Add the Angular and .NET plugins

```bash
npm install -D @nx/angular @nx-dotnet/core
```

### 5. Initialize the .NET plugin

```bash
nx g @nx-dotnet/core:init
```

This writes a root `.csproj`/nuget config and teaches Nx how to shell out to `dotnet`.

### 6. Generate the Angular app (`web`)

```bash
nx g @nx/angular:app web \
  --directory=apps/web \
  --style=scss \
  --routing=true \
  --standalone=true \
  --e2eTestRunner=none \
  --ssr=false
```

### 7. Generate the .NET Web API (`api`)

```bash
nx g @nx-dotnet/core:app api \
  --language=C# \
  --template=webapi \
  --directory=apps/api
```

This creates `apps/api/api.csproj` (ASP.NET Core Web API on .NET 8) and registers `build`, `serve`, `test`, `lint` targets in `project.json` that proxy to `dotnet`.

### 8. Verify the generators worked

```bash
nx show projects           # should list: web, api
nx build web
nx build api
```

### 9. Exit the shell and run the dev servers via Compose

```bash
exit                       # leaves the interactive container
docker compose up web      # http://localhost:4200
docker compose up api      # http://localhost:5000 (HTTP) / 5001 (HTTPS)
```

Or, to run both in parallel from a single `dev` shell:

```bash
docker compose run --rm --service-ports dev
nx run-many -t serve -p web,api --parallel=2
```

## Notes / gotchas

- **HTTPS dev certs for .NET**: the first time you hit the API you may need
  `dotnet dev-certs https --trust` — that has to be done on the host, not in
  the container. For local dev over plain HTTP the `5000` port is fine.
- **`node_modules` volume**: `docker-compose.yml` keeps `node_modules` in a
  named volume so that host/container OS mismatches (e.g. macOS host +
  Linux container) don't break native binaries like `esbuild`. If you ever
  want a clean install, run `docker compose down -v`.
- **Nx Cloud**: the plan uses `--nxCloud=skip`. If you want remote caching,
  run `nx connect` later.
- **Alternative to `@nx-dotnet/core`**: you can instead keep the .NET
  project unmanaged by Nx and just call `dotnet build`/`dotnet run` via
  `nx:run-commands` targets in `project.json`. The plugin just automates
  that wiring.
