# CI

The skill ships a tailored GitHub Actions workflow at
`assets/base/.github/workflows/ci.yml`. Drop it at
`.github/workflows/ci.yml` in the new workspace.

Why bespoke and not `nx g ci-workflow`: the stock generator only knows about
Node. It doesn't know to set up the .NET SDK, cache NuGet, cache Playwright
browsers, or set `DOTNET_NOLOGO`. We could feed it a `--ci=github` and then
patch the result, but the patch ends up being most of the file. Cleaner to
ship the full thing.

## Job at a glance

```yaml
on:
  push:    { branches: [main] }
  pull_request:

permissions: { actions: read, contents: read }

env:
  CI: 'true'
  DOTNET_NOLOGO: 'true'
  DOTNET_CLI_TELEMETRY_OPTOUT: 'true'
  NUGET_PACKAGES: ${{ github.workspace }}/.nuget/packages
  NX_CLOUD_ACCESS_TOKEN: ${{ secrets.NX_CLOUD_ACCESS_TOKEN }}
```

Runs as a single `main` job on `ubuntu-latest`. Steps:

1. **Checkout** — `actions/checkout@v6` with `filter: tree:0` and
   `fetch-depth: 0`. Both are needed for `nrwl/nx-set-shas` to resolve
   `NX_BASE` on push to `main`.
2. **(Optional) Nx Cloud DTE** — there's a commented-out
   `npx nx start-ci-run --distribute-on=…` line near the top. Uncomment
   after `npx nx connect`. Order matters: it must run **before** `npm ci`
   so agents pick up the run.
3. **Set up Node 24** — `actions/setup-node@v6` with `cache: 'npm'`.
4. **Set up .NET SDK 10.0.x** — `actions/setup-dotnet@v5`. Match the
   `<TargetFramework>net10.0</TargetFramework>` in every `.csproj`.
5. **Cache NuGet packages** — `actions/cache@v5` keyed on every `.csproj`
   plus `Directory.Packages.props` plus `global.json`. The path is
   `${{ env.NUGET_PACKAGES }}` which we set to a workspace-local folder so
   the cache action can actually pick it up (the default `~/.nuget/packages`
   on `ubuntu-latest` is owned by `runneradmin` and gets clobbered).
6. **`npm ci`** — strict-deterministic install. Don't use `npm install` in
   CI; it'll happily ignore `package-lock.json` if the resolution shifted.
7. **Derive NX_BASE / NX_HEAD** — `nrwl/nx-set-shas@v5`. Without this,
   `nx affected` falls back to "everything is affected" on push, which
   negates the entire point.
8. **Cache Playwright browsers** — keyed on `package-lock.json`. The
   subsequent install step is gated on a cache miss.
9. **Format check** — `npx nx format:check`. Cheap; fail fast on
   formatting before doing the heavy work.
10. **Lint, test, build, e2e** — `npx nx affected -t lint test build e2e`.
    Single command, no per-stack split. `affected` skips projects that
    don't define a target, so this lints + tests Angular projects, builds
    Angular and .NET projects (incl. the `^build` chain through
    `Demo.Domain`), and runs Playwright e2e — only for what changed.
11. **Self-healing CI** — `npx nx fix-ci`. No-op until the workspace is
    connected to Nx Cloud; once connected, failed tasks get
    [self-healing CI](https://nx.dev/ci/features/self-healing-ci) suggestions
    on the PR.

## Targets vs target names — a footgun

The line:

```yaml
run: npx nx affected -t lint test build e2e
```

…uses the e2e target named `e2e`. The bundled `nx.json` configures
`@nx/playwright/plugin` with `targetName: 'e2e'`, so this lines up. If you
change the target name in `nx.json#plugins.@nx/playwright` (e.g. to
`e2e-ci`), update the workflow's `-t` list to match — they're not linked
automatically.

## Nx Cloud (optional)

```sh
# 1. Connect the workspace (interactive — opens a browser to claim it)
npx nx connect

# 2. Commit the resulting nxCloudId in nx.json
git add nx.json && git commit -m "chore: connect to Nx Cloud" && git push
```

Once connected:

- Free tier — remote cache (`actions/cache` for `nx` task outputs across
  branches and PRs).
- Paid / trial — distributed task execution (DTE). Uncomment the
  `npx nx start-ci-run …` line near the top of `ci.yml`.

The `NX_CLOUD_ACCESS_TOKEN` secret needs to be set on the repo (Settings →
Secrets → Actions). Until it is, the env var is unset and Nx Cloud silently
no-ops — that's why the secret reference is unconditional in the workflow.

## Things deliberately not in the workflow

- **A separate `e2e-ci` target.** The bundled `nx.json` registers Playwright
  as `targetName: 'e2e'` and `nx affected -t e2e` is the same surface area.
  The split is sometimes useful when `e2e` runs locally with `--ui` and
  `e2e-ci` is the headless variant; for this skill we keep one target.
- **Codecov / SonarQube / etc.** Add when the project gets big enough to
  need them; bolt-on, not part of the bootstrap.
- **Matrix builds.** Only one OS / Node / .NET combination is supported by
  the bundled assets; add a matrix when you ship a real cross-platform
  product.
