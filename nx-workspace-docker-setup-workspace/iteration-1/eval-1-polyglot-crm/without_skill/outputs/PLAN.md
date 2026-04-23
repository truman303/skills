# Pollen — Nx monorepo in Docker, from zero to `nx serve` / `nx build`

Goal: starting from `~/code/pollen` containing only `README.md`, end up with
a working Nx monorepo that has an Angular app (`web`) and a .NET 8 Web API
(`api`), runnable entirely through Docker, plus Nx's AI / MCP integration
wired up for Claude Code.

No Node and no .NET SDK on the host. Every toolchain call goes through a
single `dev` container.

---

## Files added to the repo

Drop these at the root of `~/code/pollen` (they're in `sandbox-repo/` and
copied into this `outputs/` folder):

- `Dockerfile.dev` — .NET 8 SDK base + Node 20 from NodeSource, non-root
  `dev` user.
- `docker-compose.yml` — defines the `dev` service, bind-mounts the repo at
  `/workspace/pollen`, uses named volumes for `node_modules` / `.nx` /
  `/home/dev`, exposes ports 4200 / 5000 / 5001.
- `.dockerignore` — keeps build context small.
- `.mcp.json` — Claude Code MCP config pointing at Nx's MCP server, proxied
  through `docker compose exec`.
- `CLAUDE.md` — guide rail for Claude Code explaining the container-first
  workflow.

---

## Step-by-step commands (run on the macOS host unless noted)

### 1. Bring up the dev container

```bash
cd ~/code/pollen

# Build the image (Node 20 + .NET 8 SDK). First build ~2-3 min.
docker compose build dev

# Start it in the background; it just runs `sleep infinity` so we can exec in.
docker compose up -d dev

# Sanity check.
docker compose exec dev node   --version   # v20.x
docker compose exec dev dotnet --version   # 8.0.x
```

### 2. Initialize Nx in place

The repo already exists (has `README.md`) so we use `nx init` rather than
`create-nx-workspace` (which insists on creating a fresh directory).

```bash
docker compose exec dev bash -lc '
  cd /workspace/pollen &&
  npx --yes nx@latest init --nxCloud=skip
'
```

This creates `nx.json`, `package.json`, `.gitignore`, installs `nx`, and
leaves the existing `README.md` alone.

### 3. Add the Angular app

```bash
docker compose exec dev bash -lc '
  cd /workspace/pollen &&
  npx nx add @nx/angular &&
  npx nx g @nx/angular:application web \
      --directory=apps/web \
      --style=scss \
      --routing=true \
      --standalone=true \
      --ssr=false \
      --e2eTestRunner=none \
      --no-interactive
'
```

### 4. Add the .NET Web API

```bash
docker compose exec dev bash -lc '
  cd /workspace/pollen &&
  npx nx add @nx-dotnet/core &&
  npx nx g @nx-dotnet/core:init --no-interactive &&
  npx nx g @nx-dotnet/core:app api \
      --directory=apps/api \
      --language="C#" \
      --template=webapi \
      --no-interactive
'
```

`@nx-dotnet/core` generates a .NET solution file at the root, project targets
under `apps/api`, and wires `nx build` / `nx serve` / `nx test` targets that
shell out to `dotnet`.

### 5. Verify

```bash
# Angular dev server (leave running). Host 0.0.0.0 so macOS can reach it.
docker compose exec dev npx nx serve web --host 0.0.0.0 --port 4200
# → open http://localhost:4200

# In another terminal, build the api.
docker compose exec dev npx nx build api
# → produces apps/api/bin/Debug/net8.0/...

# And run it.
docker compose exec dev npx nx serve api
# → http://localhost:5000/swagger (webapi template includes Swashbuckle)

# Full project graph.
docker compose exec dev npx nx graph --file=graph.html
```

### 6. Wire up Claude Code + Nx MCP

Install Claude Code on the mac (it only needs the native binary, no Node):
follow `https://docs.claude.com/claude-code`.

`.mcp.json` is already in the repo, so:

```bash
cd ~/code/pollen
# Make sure the dev container is running - the MCP server lives inside it.
docker compose up -d dev

claude
# On first launch Claude Code will detect .mcp.json and ask to trust the
# "nx" server. Approve it. After that, ask Claude things like
# "show me the Nx project graph" or "generate a lib for shared UI" and
# it'll call the nx-mcp tools instead of blindly shelling out.
```

If you'd rather run Claude Code _inside_ the container, add an install
step to `Dockerfile.dev` or `docker compose exec -it dev bash` and invoke
`claude` there; in that case the MCP command in `.mcp.json` can be
simplified to just `npx -y nx-mcp@latest /workspace/pollen`.

---

## Day-to-day cheatsheet

| Task                    | Command                                               |
| ----------------------- | ----------------------------------------------------- |
| Start dev toolchain     | `docker compose up -d dev`                            |
| Stop it                 | `docker compose down`                                 |
| Shell in                | `docker compose exec dev bash`                        |
| Run any Nx command      | `docker compose exec dev npx nx <args>`               |
| Serve Angular           | `docker compose exec dev npx nx serve web --host 0.0.0.0` |
| Build API               | `docker compose exec dev npx nx build api`            |
| Serve API               | `docker compose exec dev npx nx serve api`            |
| Run a generator         | `docker compose exec dev npx nx g @nx/angular:lib ui` |
| Rebuild the image       | `docker compose build dev`                            |
| Nuke node_modules cache | `docker compose down -v` (wipes named volumes)        |

---

## Notes & gotchas

- **node_modules on a named volume**: install speed on macOS is ~10x faster
  than bind-mounting into virtiofs. Trade-off: `node_modules` isn't visible
  from the host (IDE intellisense that relies on it will want a
  language-server-in-container setup or a separate host install — for
  Cursor/VSCode the Dev Containers extension is the usual fix).
- **`nx init` vs `create-nx-workspace`**: the latter scaffolds into a fresh
  subdirectory; since the repo already exists we use `init` + `nx add` +
  generators to stay in place.
- **Non-root user**: the image creates a `dev` user with UID 1000. On Linux
  hosts this prevents root-owned files in the bind mount. On macOS it's
  effectively cosmetic because Docker Desktop remaps uids.
- **HTTPS for the API**: the `webapi` template emits a dev cert; inside the
  container run `dotnet dev-certs https --trust` if you need HTTPS locally.
  Port 5001 is pre-exposed for that.
- **Nx Cloud**: disabled during `nx init` (`--nxCloud=skip`). Re-enable any
  time with `npx nx connect`.
