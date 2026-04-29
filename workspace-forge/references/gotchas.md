# Gotchas

Lifted from the reference repo's README + a couple discovered while
building the skill itself. Add to this file when you hit a new one.

## 1. `@nx/dotnet` `build` doesn't restore by default

The plugin infers the `build` target as `dotnet build --no-restore --no-dependencies`
and does **not** make it `dependsOn: ["restore"]`. On a fresh clone (or in
CI) you get:

```text
error NETSDK1004: Assets file '.../obj/project.assets.json' not found.
Run a NuGet package restore to generate this file.
```

Fix: ensure `nx.json#plugins` contains the snippet from
`assets/nx-config/dotnet-plugin.snippet.json` (workspace-init step 5):

```jsonc
{
  "plugin": "@nx/dotnet",
  "options": {
    "build": { "dependsOn": ["restore", "^build"] }
  }
}
```

The plugin's options API only merges the canonical target names (`build`,
`test`, `restore`, `clean`, `publish`, `pack`, `watch`, `run`). Variants
like `build:release` are silently ignored if you put them in `options` —
so `nx pack` (which depends on `build:release`) would still fail on a fresh
clone. The skill doesn't run `pack`; if the user wires it in, they need to
either run `nx run-many -t restore` first or add an explicit project-level
override.

## 2. `nx affected -t e2e` starts a dev server

Playwright's `webServer` config boots `nx run <app>:serve:development` as a
continuous dependency of `<app>-e2e:e2e`. You'll see a `serve` line and
"Watch mode enabled" in the affected output — that's expected, it shuts
down when the e2e run finishes. Exit code 130 (SIGINT) shows up in the CI
logs for the serve task; that's the normal way Playwright tears it down.

If the e2e job hangs in CI, it's almost always because something in
`webServer.command` is wrong — most often a target name mismatch (e.g.
the workflow registers Playwright as `targetName: e2e-ci` but the
playwright.config.ts says `npx nx run demo-app:serve` with no
`reuseExistingServer`).

## 3. The two stacks can't import each other

There's no shared-code path between TypeScript and C#. The boundary is
HTTP. See `cross-stack-wiring.md` for the three ways to keep DTOs in sync.

A common stumbling block: developers familiar with monorepos that share
languages (e.g. a Go monorepo) try to put a "shared types" lib at the root
and reference it from both stacks. Don't. There's no compiler that would
honor it. Use OpenAPI codegen instead.

## 4. `@nx/angular:library` generator quirks

- The directory is the **positional argument**, the project name is `--name`.
  Mixing them up generates the lib in the wrong place under a path-shaped
  project name.
- It does not support `--dry-run`. Use `git status` after running.
- Defaults to non-buildable. Pass `--buildable` only when you actually need
  an `ng-packagr` build target (incremental builds, private registry).

## 5. `create-nx-workspace` insists on an empty directory

Running it inside a non-empty folder errors with
`The directory ... is not empty.` — even if the only contents are
`docs/PLAN.md` or a stray `.git`.

The skill's first user-visible question after detecting environment is
"is the target folder empty?" precisely so the user has time to either:

- Move the existing files out (and let the skill repopulate).
- Pick a different target.

There's no `--force` flag. Removing `.git` after the fact is fine
(`create-nx-workspace` will recreate it), but moving files out and back
in is cleaner.

## 6. `.devcontainer/devcontainer.json` formatting

devcontainer.json supports `// comments`, which standard JSON parsers
(and Prettier) reject. The bundled `.prettierignore` has the line:

```
.devcontainer/devcontainer.json
```

…specifically so `npx nx format:check` doesn't trip on it. Preserve the
line in any user-supplied `.prettierignore`. If the user runs `nx format`
once and the file disappears from the ignore list, comments survive but
JSON stays valid; the issue only bites when someone removes the ignore
*and* Prettier has been bumped to a major that's stricter about JSON
parsing.

## 7. Identifier rewrite must run on demo branch

The bundled assets in `assets/demo/` use `@nx-mixed`, `nx-mixed`, and
`&#64;nx-mixed` (HTML-encoded `@`) as placeholders. After copying them
into the new workspace you **must** run
`scripts/rewrite_identifiers.sh <root> <scope> <PascalName> <name>` or the
TS imports won't resolve and the shared-ui banner will display the wrong
package name.

The skill's flow runs the rewrite automatically at step 6a; the gotcha is
worth keeping in this list because forgetting the rewrite is the single
most likely way the demo branch ends up broken on first try.

## 8. Port 5039 is hardcoded in three places

If you change the .NET API's port, update **all three**:

- `apps/<api>/Properties/launchSettings.json` — the `applicationUrl` for
  the `http` profile.
- `apps/<app>/proxy.conf.json` — the `target` field.
- `apps/<app>/src/app/weather-forecast.ts` — the user-facing error message
  ("Make sure demo-dotnet-api is running on http://localhost:5039").

The first two are mechanical; the third is human-readable text and is the
one most often forgotten.
