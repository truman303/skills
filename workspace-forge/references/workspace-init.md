# Workspace initialization

This step turns an empty folder into a bare Nx workspace with both stacks'
plugins installed and the one nx.json override that makes `@nx/dotnet` build
correctly on a fresh clone.

## Pinned versions

Pinning makes the skill's output reproducible. The reference repo runs the
combination below; deviating means the asset files in `assets/demo/` may not
match what the generators produce.

| Tool                                | Version |
| ----------------------------------- | ------- |
| `create-nx-workspace`               | `22.7.0` |
| `nx`, `@nx/angular`, `@nx/eslint`,  | `22.7.0` |
| `@nx/playwright`, `@nx/js`, `@nx/web`, `@nx/workspace`, `@nx/vite`, `@nx/vitest` | |
| `@nx/dotnet`                        | `^22.7.0` (no exact 22.7.0 tag at time of writing — caret is fine) |
| `@angular/*`                        | `~21.2.0` |
| Node                                | `>=24` (devcontainer pins 24) |
| .NET SDK                            | `10.0.x` |

The `package.json` produced by `create-nx-workspace@22.7.0 --preset=apps`
already targets these Angular and Nx ranges; the only manual pin is the
`@nx/dotnet` plugin (added later by `nx add`).

## The exact command

Run this in the empty target folder. It must be empty, or `create-nx-workspace`
will refuse with `Error: The directory ... is not empty.`:

```sh
npx --yes create-nx-workspace@22.7.0 . \
  --preset=apps \
  --workspaceType=integrated \
  --packageManager=npm \
  --ci=skip \
  --useGitHub=false \
  --nxCloud=skip \
  --no-interactive
```

Why each flag:

- `.` — initialize **in** the current directory rather than creating a child.
- `--preset=apps` — gives an empty `apps/` + `libs/` skeleton with no example
  app preinstalled. We add apps ourselves (or copy the bundled demo).
- `--workspaceType=integrated` — single root `package.json`, single
  `node_modules`, single `nx.json`. The alternative (`package-based`) would
  be wrong for a mixed Angular/.NET monorepo because Angular's tooling
  expects the integrated layout.
- `--ci=skip` — we ship our own bespoke `ci.yml` (the stock `nx g ci-workflow`
  generator only knows about Node).
- `--nxCloud=skip` — let the user opt in later via `npx nx connect`. Doing
  it now would force them to claim a workspace mid-scaffold which is jarring.
- `--no-interactive` — refuse all prompts. Combined with the explicit flags
  above, the command is fully scripted.

## Adding the plugins

```sh
npx nx add @nx/angular@22.7.0
npx nx add @nx/dotnet
```

`nx add` does three things per plugin: installs the npm package, runs the
plugin's `init` generator (which wires up base config and devDependencies),
and registers the plugin under `nx.json#plugins`. Run them serially — both
modify `package.json` and `nx.json`, and concurrent edits race.

After `nx add @nx/angular`, the workspace has:

- `eslint.config.mjs` at the root with the standard `@nx/enforce-module-boundaries`
  scaffold.
- `tsconfig.base.json` at the root with an empty `paths` map.
- `package.json` updated with all the Angular and Nx peer deps.

After `nx add @nx/dotnet`, the workspace has:

- `@nx/dotnet` listed in `nx.json#plugins` as either the bare string
  `"@nx/dotnet"` or `{ "plugin": "@nx/dotnet" }`.

## The `nx.json#plugins` override (the critical gotcha)

`@nx/dotnet` infers `build` as `dotnet build --no-restore --no-dependencies`
and does **not** make it `dependsOn: ["restore"]`. On a fresh clone (or in CI)
that yields:

```text
error NETSDK1004: Assets file '.../obj/project.assets.json' not found.
Run a NuGet package restore to generate this file.
```

The bundled snippet at `assets/nx-config/dotnet-plugin.snippet.json` fixes it:

```jsonc
{
  "plugin": "@nx/dotnet",
  "options": {
    "build": { "dependsOn": ["restore", "^build"] }
  }
}
```

Replace whatever `nx add @nx/dotnet` left in `nx.json#plugins` with this
object. Do **not** just append — you'd end up with two `@nx/dotnet` entries
and Nx will pick whichever it sees first.

The plugin's options API only merges the canonical target names (`build`,
`test`, `restore`, `clean`, `publish`, `pack`, `watch`, `run`). Variants
like `build:release` are silently ignored if you put them in `options` —
so `nx pack` (which depends on `build:release`) would still fail on a fresh
clone. We don't run `pack` in CI today; document this in `gotchas.md` rather
than working around it here.

## Applying the base config files

After both plugins are in, copy each file under `assets/base/` to the matching
spot at the workspace root:

| Asset                                       | Destination                              |
| ------------------------------------------- | ---------------------------------------- |
| `.editorconfig`                             | `.editorconfig`                          |
| `.nvmrc`                                    | `.nvmrc`                                 |
| `.prettierrc`                               | `.prettierrc`                            |
| `.prettierignore`                           | `.prettierignore`                        |
| `.gitignore`                                | `.gitignore` (overwrite, ours is wider)  |
| `Directory.Packages.props`                  | `Directory.Packages.props`               |
| `.github/dependabot.yml`                    | `.github/dependabot.yml`                 |
| `.github/workflows/ci.yml`                  | `.github/workflows/ci.yml`               |

Note `.devcontainer/devcontainer.json` is in `.prettierignore` — preserve
that line so the devcontainer JSON's comments don't get reformatted away.

The bundled `Directory.Packages.props` enables central package management
but pre-pins nothing; the demo's only direct package reference
(`Microsoft.AspNetCore.OpenApi`) stays inline in its `.csproj` until the user
opts in (see comment in the file).

## (Optional) root `.sln`

Nx itself doesn't need a solution file, but IDEs and `dotnet build NxMixed.sln`
work better with one. After the demo or new-app branch creates `.csproj`
files, run from the workspace root:

```sh
dotnet new sln --name <PascalCaseName>
dotnet sln <PascalCaseName>.sln add **/*.csproj
```

Use the workspace's PascalCase identifier (computed in step 2 of `SKILL.md`).
