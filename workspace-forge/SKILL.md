---
name: workspace-forge
description: Build a brand-new Nx monorepo that mixes Angular 21 and .NET 10 from scratch. Use this skill whenever the user wants to set up an Nx workspace, scaffold a monorepo with Angular and .NET, mix Angular and .NET in one repo, bootstrap a dev container for an Nx repo, get a working `npm run demo` end-to-end, or stand up CI for an Angular + .NET project — even if they don't say "workspace-forge" by name. Trigger on phrases like "set up an Nx workspace", "create an Nx monorepo", "Angular and .NET in one repo", "scaffold a mixed-stack monorepo", "bootstrap an Nx repo", or "I want a fresh repo with Angular and an ASP.NET API". Do NOT use this skill for adding apps/libs to an *existing* workspace — `nx-generate` covers that. This skill is specifically about the **first build** of the repo.
---

# Workspace Forge

Walks the user from an empty folder to a green `npm run demo` (Angular 21 +
.NET 10 over HTTP, both apps orchestrated by Nx) plus a tailored CI workflow.
Everything is pinned to versions known to work together; deviating means the
bundled assets in `${SKILL_DIR}/assets/` may stop matching what the
generators emit.

`${SKILL_DIR}` throughout this file means the skill's own directory —
`.agents/skills/workspace-forge/` (or wherever the runtime mounted it). All
asset paths below resolve relative to it.

## What the skill ships

```
${SKILL_DIR}/
├── SKILL.md                           you are here
├── references/                        deep-dive per topic; read on demand
│   ├── devcontainer.md
│   ├── workspace-init.md
│   ├── angular-app.md
│   ├── dotnet-api.md
│   ├── library-generation.md
│   ├── cross-stack-wiring.md
│   ├── ci.md
│   ├── module-boundaries.md
│   └── gotchas.md
├── assets/                            files that get copied verbatim
│   ├── devcontainer/                  → .devcontainer/
│   ├── base/                          → workspace root config + .github/
│   ├── nx-config/dotnet-plugin.snippet.json
│   └── demo/                          → apps/ + libs/ for the smoke test
└── scripts/rewrite_identifiers.sh     `@nx-mixed`/`NxMixed`/`nx-mixed` rewriter
```

The demo tree under `assets/demo/` keeps the placeholder identifiers
(`@nx-mixed`, `nx-mixed`, `&#64;nx-mixed`) intentionally unrewritten, so the
rewrite step has work to do at copy time.

---

## Step 0 — Detect the environment

Run these checks **before** doing anything destructive. Their results pick
the path through the rest of the flow.

| Question                       | How to check                                                                                  |
| ------------------------------ | --------------------------------------------------------------------------------------------- |
| Inside a devcontainer already? | `[ -n "${REMOTE_CONTAINERS:-}${CODESPACES:-}" ] || [ -f /.dockerenv ]`                        |
| Host OS?                       | `uname -s` (`Linux`, `Darwin`, or `MINGW64_NT-…` / `MSYS_NT-…` for Git-Bash on Windows)        |
| Target folder empty?           | `ls -A "$TARGET" 2>/dev/null`. Must be empty (allow `.git/` if you intend to keep it).        |
| Node 24+ on `PATH`?            | `node --version`. Below 24 is a hard stop.                                                    |
| .NET 10 SDK on `PATH`?         | `dotnet --list-sdks                                            \| grep -E '^10\.' \| head -1` |

If the target folder isn't empty, **stop** and ask the user to either
clear it or pick a different one. `create-nx-workspace` will refuse with
`The directory ... is not empty.` and there's no `--force` flag — see
`references/gotchas.md` §5.

---

## Step 1 — Devcontainer (skip if already inside one)

**Use the bundled devcontainer when:** host is Windows, OR Node 24 / .NET 10
isn't installed natively, OR the user explicitly asks for "same env as CI".

**Skip when:** already inside a devcontainer/Codespace, OR host is Linux/macOS
with both runtimes installed natively and the user opted out.

To stage it, copy from `${SKILL_DIR}/assets/devcontainer/` to `.devcontainer/`
at the workspace root:

```sh
mkdir -p .devcontainer
cp ${SKILL_DIR}/assets/devcontainer/devcontainer.json   .devcontainer/devcontainer.json
cp ${SKILL_DIR}/assets/devcontainer/docker-compose.yml  .devcontainer/docker-compose.yml
cp ${SKILL_DIR}/assets/devcontainer/Dockerfile          .devcontainer/Dockerfile
```

Then **halt and tell the user**:

> The devcontainer config is staged. To continue, open this folder in VS Code
> and run **Dev Containers: Reopen in Container** (Ctrl/Cmd-Shift-P). Once
> you're back at the prompt inside the container, ping me and I'll resume
> from step 2.

Don't keep going on the host — the rest of the skill assumes a Linux
environment and the bundled `ci.yml` runs on `ubuntu-latest`. See
`references/devcontainer.md` for what's in the bundle and why the Postgres
sidecar is included even though the demo doesn't use it.

---

## Step 2 — Workspace identity

Ask the user for three names. Default values in parentheses:

| Field                    | Example          | Used for                                      |
| ------------------------ | ---------------- | --------------------------------------------- |
| Workspace folder name    | `acme-platform`  | `package.json#name`, READMEs                  |
| npm scope (without `@`)  | `acme`           | TS path aliases (`@acme/<lib>`)               |
| PascalCase project name  | `AcmePlatform`   | Future `.sln` name, .NET namespaces           |

If the user only gives one name, derive the others:

- workspace folder name: the input lowercased and kebab-cased
- npm scope: same as workspace folder name (matching what this skill's
  source repo does — `@nx-mixed` ↔ `nx-mixed`)
- PascalCase: split on `-`/`_`/space, title-case each segment, join

Confirm the three derived values with the user before proceeding. They
become arguments to `scripts/rewrite_identifiers.sh` later, and getting
them wrong means re-cloning to fix.

---

## Step 3 — Bare workspace

From the empty target folder:

```sh
npx --yes create-nx-workspace@22.7.0 . \
  --preset=apps \
  --workspaceType=integrated \
  --packageManager=npm \
  --ci=skip \
  --useGitHub=false \
  --nxCloud=skip \
  --no-interactive

npx nx add @nx/angular@22.7.0
npx nx add @nx/dotnet
```

Why each flag and what `nx add` does is covered in
`references/workspace-init.md`. Read that file before running this step
the first time — there's a single critical override on `nx.json#plugins`
that prevents a `NETSDK1004 assets file not found` failure on every fresh
clone.

After both `nx add` commands complete, **patch `nx.json`**: locate the
`plugins` array, find whatever `nx add @nx/dotnet` left (either the bare
string `"@nx/dotnet"` or `{ "plugin": "@nx/dotnet" }`), and **replace** it
with the contents of `${SKILL_DIR}/assets/nx-config/dotnet-plugin.snippet.json`:

```jsonc
{
  "plugin": "@nx/dotnet",
  "options": {
    "build": { "dependsOn": ["restore", "^build"] }
  }
}
```

Don't append — duplicate `@nx/dotnet` entries make Nx pick whichever it
sees first, defeating the override. See `references/gotchas.md` §1.

Now apply the rest of the base config:

```sh
SF=${SKILL_DIR}
cp $SF/assets/base/.editorconfig            .editorconfig
cp $SF/assets/base/.nvmrc                   .nvmrc
cp $SF/assets/base/.prettierrc              .prettierrc
cp $SF/assets/base/.prettierignore          .prettierignore
cp $SF/assets/base/.gitignore               .gitignore         # overwrite
cp $SF/assets/base/Directory.Packages.props Directory.Packages.props
mkdir -p .github/workflows
cp $SF/assets/base/.github/dependabot.yml         .github/dependabot.yml
cp $SF/assets/base/.github/workflows/ci.yml       .github/workflows/ci.yml
```

Don't try to be clever and merge our `.gitignore` into `create-nx-workspace`'s —
ours is a strict superset. Same for `.prettierignore`.

---

## Step 4 — Pick a follow-up

Ask the user:

> Want a working end-to-end demo (Angular table populated by a .NET API,
> already wired up — best if you want a smoke test that proves everything
> talks), or an empty Angular + .NET app pair to start from scratch?

- **Demo** → step 5a.
- **Empty pair** → step 5b.

If they're not sure, default to the demo. The smoke test is more useful as
a confidence check, and they can `rm -rf` the demo apps later.

---

## Step 5a — Demo branch (smoke test)

Copy the entire `${SKILL_DIR}/assets/demo/` tree into the workspace root,
preserving its `apps/…` and `libs/…` layout:

```sh
cp -r ${SKILL_DIR}/assets/demo/. .
```

The dot at the end of the source path matters: `demo/.` copies the
**contents** into `.`, not a `demo/` folder. Verify with `ls apps libs`.

Run the identifier rewrite. Pass the three values from step 2 (the
example uses `acme-platform`, `acme`, `AcmePlatform`):

```sh
${SKILL_DIR}/scripts/rewrite_identifiers.sh . <scope> <PascalName> <name>
# e.g.
# ${SKILL_DIR}/scripts/rewrite_identifiers.sh . acme AcmePlatform acme-platform
```

The script handles three placeholder forms: `@nx-mixed`, `&#64;nx-mixed`
(HTML-encoded `@`, used in `shared-ui.html` because `@` collides with
Angular's control-flow syntax), and bare `nx-mixed`. Order of substitutions
matters; the script handles it. See `references/gotchas.md` §7.

Now wire the path alias for the `shared-ui` lib. Open `tsconfig.base.json`
and add to `compilerOptions.paths`:

```jsonc
"@<scope>/shared-ui": ["./libs/web/shared/ui/shared-ui/src/index.ts"]
```

Substituting the actual scope (e.g. `@acme/shared-ui`). The path alias is
what `import { SharedUi } from '@acme/shared-ui'` in `app.ts` resolves
against. Without it, Angular's compiler errors with `Cannot find module`.

The reason this isn't auto-handled by the rewrite script: `tsconfig.base.json`
is a workspace-root file (not under `apps/` or `libs/`), and adding the
path is the kind of structured-JSON edit that's safer to do explicitly than
via sed.

Then install, build, and verify:

```sh
npm install
npx nx run-many -t lint test build
```

Expect:

- `Demo.Domain:build` runs before `demo-dotnet-api:build` (the `^build`
  chain via the `<ProjectReference>`).
- `shared-ui:test` runs (vitest-analog).
- `demo-app:lint` and `demo-app:build` succeed.
- `demo-app-e2e` is skipped at `build` (no `build` target) and only runs
  on `e2e`.

Run the demo:

```sh
npm run demo
# in a second shell:
curl http://localhost:4200/api/weatherforecast | head
```

You should see five JSON forecasts. If you see Angular's `index.html`,
the proxy isn't wired (re-check `apps/demo-app/project.json`'s
`serve.options.proxyConfig` and `apps/demo-app/proxy.conf.json`). If you
see a connection error, the .NET API isn't on port 5039 — see
`references/gotchas.md` §8 for all three places port 5039 is hardcoded.

---

## Step 5b — New-app branch (empty Angular + .NET pair)

Ask the user for:

- Angular app name (default: `web`)
- .NET API name (default: `api`)
- A name for the first .NET class lib (default: `<PascalName>.Domain`,
  e.g. `AcmePlatform.Domain` — this is the Demo.Domain analog and exists
  to prove the `^build` chain).

### Generate the Angular app

```sh
npx nx g @nx/angular:application apps/<app-name> \
  --name=<app-name> \
  --e2eTestRunner=playwright \
  --unitTestRunner=vitest-angular \
  --linter=eslint \
  --style=scss \
  --prefix=app \
  --routing \
  --standalone \
  --no-interactive
```

Then apply the **three overlays** the generator doesn't do — proxy +
HttpClient + serve-target wiring. Step-by-step in
`references/angular-app.md`. Skipping any of them means the proxy doesn't
proxy or `HttpClient` injection throws at runtime.

### Generate the .NET API

```sh
dotnet new web -o apps/<api-name> -f net10.0
```

Then port-pin to 5039 and move any inline `WeatherForecast`-style record
out to a class lib so the `^build` chain has something to prove. Details
in `references/dotnet-api.md`.

### Wire the API to the class lib

```sh
dotnet new classlib -o libs/dotnet/<DomainLib> -f net10.0
dotnet add apps/<api-name>/<api-name>.csproj reference \
  libs/dotnet/<DomainLib>/<DomainLib>.csproj
```

Verify with `npx nx graph` — the new edge should be visible.

---

## Step 6 — Verifying

Always run, on either branch:

```sh
npx nx format:check
npx nx affected -t lint test build e2e
npm run demo
```

`affected` against an empty `NX_BASE` ends up touching everything, which is
fine for a fresh workspace. The `format:check` is the cheapest way to catch
a stray identifier-rewrite glitch (e.g. a leftover `@nx-mixed` that didn't
get rewritten).

If `npm run demo` fails, the failure mode is almost always one of:

- Port 5039 conflict — something else is using it.
- Proxy misrouted — `apps/<app>/proxy.conf.json` `target` doesn't match the
  .NET API's actual port.
- `Cannot find module '@<scope>/shared-ui'` — `tsconfig.base.json` path
  alias missing.

---

## Step 7 — Follow-ups (suggest, don't run)

Mention these to the user at the end. Don't run them automatically; each
involves a decision the user should make.

- **Connect Nx Cloud** — `npx nx connect`. Free remote cache, optional paid
  DTE. The bundled `ci.yml` already has the env var wired and a commented
  `nx start-ci-run` line for DTE. See `references/ci.md`.
- **Module boundaries** — once there are ≥2 libs in `libs/web/`, replace the
  empty placeholder in the workspace's `eslint.config.mjs` with real
  `depConstraints`. See `references/module-boundaries.md`.
- **OpenAPI codegen** — the demo's `Program.cs` already calls `AddOpenApi()`,
  so the next step is generating a typed TS client from `/openapi/v1.json`
  into `libs/web/shared/data-access/api-client`. See
  `references/cross-stack-wiring.md`.
- **Root `.sln`** — `dotnet new sln --name <PascalName> && dotnet sln <PascalName>.sln add **/*.csproj`. Nx
  doesn't need it; IDEs do.

---

## Reference index

For depth on any one topic:

- `references/devcontainer.md` — when to use the bundled devcontainer,
  what's in it, the stop-and-resume protocol.
- `references/workspace-init.md` — pinned versions, exact `create-nx-workspace`
  flags, the `@nx/dotnet` plugin override (the most consequential gotcha).
- `references/angular-app.md` — the three overlays for the new-app branch
  (`provideHttpClient`, proxy.conf.json, `serve.options.proxyConfig`).
- `references/dotnet-api.md` — port pinning, ProjectReference wiring,
  optional test project setup.
- `references/library-generation.md` — `libs/web/<product>/<module>/<type>/<name>`
  taxonomy vs flat `libs/dotnet/<Pascal.Name>`.
- `references/cross-stack-wiring.md` — three options for keeping DTOs in
  sync; demo uses option 1, recommend option 2 next.
- `references/ci.md` — annotated walkthrough of `ci.yml`; why bespoke and
  not `nx g ci-workflow`.
- `references/module-boundaries.md` — the `scope:` + `type:` rule set, when
  to enable.
- `references/gotchas.md` — eight running items, plus space to add more
  while testing the skill.
