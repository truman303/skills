# Attach to a modular monolith (hydra-v3)

Use this instead of greenfield scaffolding when the UI is a delivery surface on an existing Java process.

hydra-v3 is a walking skeleton: collector → `SpineBus` → registry/MDM/orchestration → Citus, with Prometheus on 9464 and Grafana on 3000. The operator UI was named in the design (JTE + Datastar) and never started. Grafana is the operational-metrics choice. The UI is things you *do*.

## What you add

A Gradle module `:hes-ui` (context 6). Package `za.co.ipay.hydra.v3.ui`.

It is not a domain. It does not get its own schema. It does not subscribe to the bus.

```
hes-ui/
├── build.gradle
├── src/main/java/za/co/ipay/hydra/v3/ui/
│   ├── UiServer.java              # Javalin start/stop
│   ├── web/                       # adapters, SSE, stub auth
│   ├── dashboard/DashboardRoutes.java
│   └── campaigns/CampaignRoutes.java   # first feature, typical
└── src/main/jte/
    ├── layout/page.jte
    ├── dashboard/index.jte
    └── campaigns/...
```

## settings.gradle

```groovy
include(':hes-ui')
```

Place it with the other context modules. Not under composite-only.

## `hes-ui/build.gradle`

```groovy
plugins {
    id 'java-library'
    id 'gg.jte.gradle'
}

jte {
    generate()
}

dependencies {
    implementation project(':spine-contracts')
    implementation project(':registry-api')
    implementation project(':audit-api')
    implementation project(':alarms-api')
    implementation project(':orchestration')

    implementation "io.javalin:javalin:${rootProject.javalinVer}"
    implementation "io.javalin:javalin-rendering-jte:${rootProject.javalinVer}"
    implementation "dev.data-star:datastar-java-sdk-core:${rootProject.datastarVer}"
}
```

Add `javalinVer`, `jteVer`, `datastarVer` to the root `ext {}` next to `micrometerVer`. Put the JTE plugin on the root so the subproject can apply it without a version:

```groovy
// root build.gradle
plugins {
    id 'gg.jte.gradle' version '3.2.4' apply false
}
```

Then `hes-ui` uses `id 'gg.jte.gradle'` with no version. Do not add Jdbi/Flyway here unless the UI truly needs its own tables. It should not.

`:orchestration` has no `orchestration-api` leaf yet. Depending on the service module is the honest current seam. Do **not** depend on `:registry`, `:mdm`, `:audit` implementation modules. If you need a query that only lives on an impl, that is a missing published port. Add the port in the owning context, then call it. Do not reach through.

## Composition root

`SkeletonApp` already builds `OrchestrationService`, ingest, etc. Construct `UiServer` there and close it on shutdown.

```java
int uiPort = Integer.parseInt(env("UI_PORT", "8080"));
UiServer ui = new UiServer(uiPort, orchestration, identity, /* other ports */);
ui.start();
```

Keep `MetricsHttpServer` on 9464. Prometheus scrape is already pointed at it. Folding `/metrics` into Javalin is a later nicety, not part of first UI.

`MetricsHttpServer`'s javadoc says it exists until the operator UI lands. That comment is historical. Do not delete the scrape server in the same change as the first page unless the user asks. Grafana working > one fewer HTTP stack.

## ArchUnit

`architecture/src/test/.../ArchitectureTest.java` must learn about `..ui..`.

Allow:

- `..ui..` → `..registry.api..`, `..audit.api..`, `..alarms.api..`, `..orchestration..`, `..contracts..`

Forbid:

- `..ui..` → `..registry.impl..`, `..audit.impl..`, `..mdm..`, `..collector..`, `..alarms.impl..`
- every existing context → `..ui..` (the UI is a client)

The app module (`..app..`) may construct `UiServer`. That is the composition root's job.

## Auth stub

Context 11 RBAC is deferred. For the prototype:

- Env `UI_AUTH=off` (default in play): every request is the operator `hydra`.
- `UI_AUTH=on`: a single password from env, session cookie, login page from [login-page.md](login-page.md).

Do not create a `users` table on the Citus coordinator for this. Do not copy greenfield bcrypt users.

## First screens

Build in this order unless the user picks otherwise:

1. **Dashboard.** Counts already in memory (`ingest.storedReadingCount()`, quarantine, `orchestration.tasks().dispatchedCount()`, campaign progress). Link to Grafana `http://localhost:3000` (dashboard uid `hydra-toa`). See [dashboard-page.md](dashboard-page.md) and [observability.md](observability.md).
2. **Campaign trigger + live progress.** Form posts to `OrchestrationService.startTariffCampaign`. Live panel uses SSE. Read `campaignProgress`. Never `bus.subscribe`.
3. Later: registry list via `TargetQuery` / `IdentityResolver`, quarantine list if MDM grows a published reader, single-meter TOA via `requestToaDelivery`.

## Live views

Virtual thread per SSE connection is cheap on Javalin 7 with `useVirtualThreads = true`.

```java
app.get("/campaigns/{id}/live", ctx -> {
    Sse.stream(ctx, sse -> {
        String last = "";
        while (!Thread.currentThread().isInterrupted()) {
            var html = render("campaigns/progress.jte", progressView(id));
            if (!html.equals(last)) {
                sse.patch("#campaign-progress", html);
                last = html;
            }
            Thread.sleep(Duration.ofMillis(500));
        }
    });
});
```

If the projection is in-process, 500ms polling is enough. Do not invent a listener interface on `OrchestrationService` until a second subscriber needs it.

## Ports and URLs

| What | URL | Already exists? |
|-------|-----|------------------|
| Operator UI | `http://localhost:8080` | New |
| Prometheus scrape | `http://localhost:9464/metrics` | Yes |
| Grafana | `http://localhost:3000` | Yes |
| Prometheus | `http://localhost:9090` | Yes |

The design watch-item "pin a Datastar version" is this skill's bundled `datastar.js` + SDK `1.0.0`.

## What not to do

- Do not `includeBuild` hydra (`-PhydraComposite`) to get a UI. The default build is enough.
- Do not put JTE templates in `app-skeleton`. The UI module is the delivery surface. `app-skeleton` only starts it.
- Do not add Spring, Guice, or Hibernate "while we're here".
- Do not build a chart in JTE because Grafana feels like a different tab. It is supposed to be a different tab.
