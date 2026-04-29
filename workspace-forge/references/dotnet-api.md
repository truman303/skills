# .NET API

Two paths:

1. **Demo branch** — copy `assets/demo/apps/demo-dotnet-api/` verbatim and
   the .NET dependency on `Demo.Domain` is already wired via
   `<ProjectReference>` in the `.csproj`. Identifier rewrite is a no-op for
   .NET in this skill (no `NxMixed` namespaces in the demo).
2. **New-app branch** — `dotnet new web`, then a manual `<ProjectReference>`
   step.

## Why `dotnet new` and not an Nx generator

`@nx/dotnet` does **not** ship a generator. It only provides target
inference: every `*.csproj` it finds gets `build`, `restore`, `clean`,
`publish`, `pack`, `watch`, `run`, `test` targets without a `project.json`.
That means the standard `dotnet` CLI is the right tool for creating projects;
the plugin picks them up on the next `nx` invocation.

## Creating the API

From the workspace root:

```sh
dotnet new web -o apps/<api-name> -f net10.0
```

Why each piece:

- `web` template — minimal ASP.NET Core; gives you `Program.cs` and a working
  `MapGet` endpoint. The fancier templates (`webapi`, `webapi-aot`) drag in
  controllers / OpenAPI / AOT we don't need for a smoke test.
- `-o apps/<api-name>` — match the Nx convention. The folder name becomes
  the Nx project name automatically.
- `-f net10.0` — pin to the .NET 10 SDK that the bundled `ci.yml` and
  `Directory.Packages.props` assume.

The generated `Program.cs` ships with a `WeatherForecast` record defined
inline at the bottom. **Move it out** to `libs/dotnet/Demo.Domain/` (or
your own domain lib) — that's the only way the `<ProjectReference>` chain
proves anything. See the demo's
`assets/demo/libs/dotnet/Demo.Domain/WeatherForecast.cs` for the exact form.

## Port pinning (5039)

The bundled `proxy.conf.json` and Playwright config both target port 5039.
Match it in `apps/<api-name>/Properties/launchSettings.json`:

```jsonc
"profiles": {
  "http": {
    "commandName": "Project",
    "applicationUrl": "http://localhost:5039",
    "environmentVariables": { "ASPNETCORE_ENVIRONMENT": "Development" }
  }
}
```

Without this, `dotnet run` picks a random free port at first launch and
prints it to stdout, which is fine if you're a human reading the log but
breaks the proxy and `npm run demo` immediately.

If you change 5039, update both `apps/<app-name>/proxy.conf.json` (target)
and the line in `assets/demo/apps/demo-app/src/app/weather-forecast.ts`
where it tells the user where the API should be running.

## ProjectReference wiring

```sh
dotnet add apps/<api-name>/<api-name>.csproj reference \
  libs/dotnet/<DomainLib>/<DomainLib>.csproj
```

Pass full `.csproj` paths. The shorthand (`dotnet add ... reference
libs/dotnet/<DomainLib>`) expects exactly one `.csproj` in the directory,
which is fine but explicit paths are clearer and don't break when you add
a `.Tests` project alongside.

Verify with:

```sh
npx nx graph
```

You should see an edge from `<api-name>` to `<DomainLib>`. The next
`npx nx build <api-name>` will run `<DomainLib>:build` first via the
inferred `^build` dependency (assuming the `nx.json#plugins` override from
`workspace-init.md` is in place — without it, the build will fail with
NETSDK1004).

## OpenAPI / dev-time

The demo's `Program.cs` calls `builder.Services.AddOpenApi()` and
`app.MapOpenApi()` in development. That gives you `http://localhost:5039/openapi/v1.json`
out of the box, which is the input you'd feed to `openapi-typescript` later
if you want typed clients (see `cross-stack-wiring.md`).

It's a no-op in production (`if (app.Environment.IsDevelopment())`), so
shipping it costs nothing.

## .NET test project (optional but trivial)

```sh
dotnet new xunit -o libs/dotnet/<DomainLib>.Tests -f net10.0
dotnet add libs/dotnet/<DomainLib>.Tests/<DomainLib>.Tests.csproj reference \
  libs/dotnet/<DomainLib>/<DomainLib>.csproj
```

`@nx/dotnet` recognizes the xunit/MSTest/NUnit templates and gives the
project a `test` target automatically. `nx affected -t test` will pick it up
without any further wiring.
