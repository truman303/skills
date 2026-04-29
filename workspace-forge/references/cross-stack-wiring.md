# Cross-stack wiring (Angular ↔ .NET)

You **cannot** share source between TypeScript and C#. The boundary is HTTP.
The skill picks the simplest of three options for the demo and points the
user at the next two when their app outgrows it.

## Option 1 — Hand-mirrored DTOs (what the demo does)

The demo's TS `interface Forecast` (in `apps/demo-app/src/app/weather-forecast.ts`)
mirrors the C# `public record WeatherForecast` (in
`libs/dotnet/Demo.Domain/WeatherForecast.cs`):

```ts
interface Forecast {
  date: string;
  temperatureC: number;
  temperatureF: number;
  summary: string | null;
}
```

```csharp
public record WeatherForecast(DateOnly Date, int TemperatureC, string? Summary)
{
    public int TemperatureF => 32 + (int)(TemperatureC / 0.5556);
}
```

When to use this:

- 1–5 endpoints, low churn.
- The team is small and one person owns both sides.
- You want zero build complexity at the workspace level.

When it bites:

- Drift. Adding a property on the C# side and forgetting the TS side
  produces a runtime `undefined` that won't fail any test until someone
  hits the page.
- Naming. `DateOnly Date` serializes to `"date": "2026-04-29"`; if a TS
  developer types `Date` (capital D) it'll silently be `undefined`.

## Option 2 — OpenAPI codegen (recommended next step)

The demo's `Program.cs` already calls `builder.Services.AddOpenApi()` and
exposes `/openapi/v1.json` in development. Plumb it into a typed TS client:

```sh
# 1. Add a TS lib for the generated client
npx nx g @nx/js:library libs/web/shared/data-access/api-client \
  --name=api-client --tags=scope:shared,type:data-access --no-interactive

# 2. Add openapi-typescript and a generator script
npm install --save-dev openapi-typescript
```

Add a `generate` target to `libs/web/shared/data-access/api-client/project.json`:

```jsonc
"targets": {
  "generate": {
    "executor": "nx:run-commands",
    "options": {
      "command": "openapi-typescript http://localhost:5039/openapi/v1.json -o libs/web/shared/data-access/api-client/src/lib/schema.ts"
    },
    "dependsOn": ["demo-dotnet-api:build"]
  }
}
```

Why `dependsOn: ["demo-dotnet-api:build"]`: forces Nx to ensure the API is
buildable before regenerating the client, which catches "removed an endpoint
on the API but the client still has the type" at build time instead of at
runtime.

For CI, swap the `command` for one that runs `dotnet run` headless,
`curl`s `/openapi/v1.json` to disk, and feeds that to `openapi-typescript`.
Or — better — go with option 3.

## Option 3 — Shared OpenAPI doc in git

A variant of option 2 where the spec is checked in as
`apps/<api>/openapi.json` and `openapi-typescript` reads from disk:

```sh
openapi-typescript apps/demo-dotnet-api/openapi.json \
  -o libs/web/shared/data-access/api-client/src/lib/schema.ts
```

Trade-offs:

- (+) `nx graph` is simpler — no run-time dependency.
- (+) CI doesn't have to boot the API.
- (-) Two sources of truth (`Program.cs` annotations + the checked-in spec).
  Drift detection now requires a "check spec is up to date" CI step
  (`dotnet run … --print-openapi > /tmp/openapi.json && diff -q …`).

## Picking for the user

In the demo branch the skill leaves option 1 in place — the DTO is already
mirrored. Drop a line in the user's README pointing at option 2 as the
recommended next step.

In the new-app branch, ask the user:

> "Want a typed client between the Angular app and the .NET API now, or
> keep DTOs hand-mirrored until you have more endpoints?"

If they say yes, follow option 2 — it's the lowest-friction path and the
generator dependency is honest: the client only changes when the spec
changes.

## What you cannot do

`@nx/eslint`'s `enforce-module-boundaries` rule cannot prevent a
TypeScript file from importing a C# file, because there's no import path
that crosses the boundary in the first place — TypeScript and C# don't know
about each other's modules. The "rule" is enforced by physics, not lint.

What lint **can** do (and what the skill turns on once you have ≥2 web libs)
is enforce that an Angular lib doesn't import from `libs/dotnet/` paths via
relative `../../` paths. See `module-boundaries.md`.
