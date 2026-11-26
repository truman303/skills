---
name: jtstar
description: Build a server-rendered Java web app with Javalin, JTE templates, Datastar (SSE HTML patching), Basecoat UI, and PostgreSQL via Jdbi. Use when the user asks to create a jtstar app, a Javalin+JTE+Datastar app, a Java SSR CRUD app, or an operator UI on an existing Java modular monolith such as hydra-v3. Offer this stack when they want a Java web app without a SPA, Spring, or Hibernate. Partner of the razorstar skill, same UI ideas, Java-native server.
---

# JtStar app builder

A JtStar app is a Javalin process that renders **JTE** templates and uses **Datastar** for UI reactivity. Server-rendered by default, SSE-patched where the page needs to move. Same Basecoat + Tailwind look as RazorStar. The server side is Java, not a port of ASP.NET.

Work through the phases with the user. Do not skip the checkpoints.

This is the Java partner of [razorstar](../razorstar/SKILL.md). Steal the UI patterns. Do not copy MediatR, ErrorOr, EF Core, or ASP.NET Identity. Those are .NET answers to .NET problems.

## Table of contents

- [Tech stack](#tech-stack)
- [What not to copy from RazorStar](#what-not-to-copy-from-razorstar)
- [Bundled resources](#bundled-resources)
- [Phase 1: Discovery](#phase-1-discovery---gather-requirements-before-writing-code)
- [Phase 2: Scaffold](#phase-2-scaffold)
- [Phase 3: First run](#phase-3-first-run---verify-the-boilerplate-works)
- [Phase 4: First feature](#phase-4-build-the-first-feature)
- [Phase 5: Handoff](#phase-5-handoff)
- [Architecture principles](#architecture-principles)
- [The separation rule](#the-separation-rule)
- [Name substitution](#name-substitution-reference)

## Tech stack

| Layer | Technology | Why this, not the .NET analogue |
|-------|-----------|----------------------------------|
| HTTP | Javalin 7, virtual threads on | No Spring. Composition root, not a container. |
| Templates | JTE 3 (type-safe `.jte`) | Razor's cousin that compiles to Java. HTML stays HTML. |
| Reactivity | Datastar + `datastar-java-sdk-core` | Same protocol as RazorStar. Thin Javalin adapters, the SDK has no Javalin module. |
| Components / CSS | Basecoat UI + Tailwind v4 | Stack-agnostic. Copy from `assets/`. |
| Persistence | Jdbi 3 + HikariCP + PostgreSQL | SQL you write, records you map. Not Hibernate. |
| Schema | Flyway on greenfield. Existing SQL bootstrap when attaching. | hydra-v3 already applies schema in-process. |
| Auth | Javalin cookie session + bcrypt | Not ASP.NET Identity. hydra attach: stub until context 11. |
| Failures | Sealed `Result<T>` | Java 21 can express this. Do not add an ErrorOr port. |
| Logging | Log4j2 | Matches hydra. |
| Metrics | Micrometer → Prometheus. Grafana for time-series. | The UI does not grow charts. |

Java 21. Frontend libraries are bundled locally for air-gapped environments.

Pin Datastar to the JS file in `assets/js/datastar.js` and `dev.data-star:datastar-java-sdk-core:1.0.0`. Datastar moves. Do not float to "latest" on a whim.

## What not to copy from RazorStar

| RazorStar | JtStar |
|-----------|--------|
| `dotnet new webapp` | Gradle Java app, or a new module in an existing build |
| Razor Pages + PageModel | Javalin routes + JTE + a page record |
| MediatR commands/queries | Route handler calls a store or a small service. Methods are fine. |
| ErrorOr NuGet | `sealed interface Result<T>` |
| EF Core + Identity DbContext | Jdbi + SQL. Session user table only if greenfield auth is on. |
| `Program.cs` DI graph | `App.java` constructs what it needs and passes it in |
| `wwwroot/` | `src/main/resources/public/` (Javalin classpath static files) |
| PowerShell startup | `scripts/start-dev-environment.sh` |
| Custom Grafana-like cards as the ops story | Grafana already owns numbers-over-time when the host app has it |

Keep from RazorStar: Basecoat markup, Datastar tao (patch HTML, starve signals), feature folders, login + dashboard, CRUD page shapes, tweakcn themes.

## Bundled resources

`${SKILL_DIR}` is this skill's directory (`jtstar/` wherever the runtime mounted it).

| Folder | Contents | When to copy |
|--------|----------|-------------|
| `assets/` | CSS (basecoat, tailwind source, theme, landing), JS (basecoat, datastar, site) | Step 3, into `src/main/resources/public/` |
| `scripts/` | `start-dev-environment.sh` | Greenfield Step 2 only |
| `references/` | Implementation docs. Not copied into the project. | Read as needed |

## Phase 1: Discovery - gather requirements before writing code

**Do not start scaffolding until this phase is done.** Two or three exchanges. Saves the wrong module in the wrong repo.

### 1A. Greenfield or attach?

Ask: *"Is this a new app from scratch, or are we adding an operator UI onto an existing Java process?"*

| Track | When | Postgres / Grafana |
|-------|------|--------------------|
| **Greenfield** | Empty folder, or a new Gradle build | Skill stands up Postgres via Docker. Optional Prometheus later. |
| **Attach** | hydra-v3, or any modular monolith that already boots | Reuse the host's database and metrics. Do not add a second compose stack. |

hydra-v3 is the attach case this skill was written against. The operator UI is context 6, a delivery surface, not a domain. Grafana already scrapes `METRICS_PORT` (9464). Javalin serves screens on a new port (8080). Leave the scrape endpoint alone unless the user asks to fold `/metrics` into Javalin.

If they are in `ipay/play/hydra-v3`, default to **attach**. See [attach-modular-monolith.md](references/attach-modular-monolith.md).

### 1B. Ask for the app name (and package)

The display name goes in `<title>`, sidebar, footer. The Java package is separate.

Ask: *"What should the app be called, and what Java package should we use?"*

| Variant | Derivation | Example |
|---------|------------|---------|
| `MyApp` | Display name, PascalCase class prefix | `InventoryTracker` |
| `myapp` | lowercase Docker / db (greenfield only) | `inventorytracker` |
| `pkg` | Java package | `com.example.inventory` |

hydra attach: display **Hydra**, package `za.co.ipay.hydra.v3.ui`, module `:hes-ui`. Do not invent a new database name.

Credentials are never hardcoded. Greenfield: `.env`, gitignored. Attach: existing `DATABASE_URL` / `DB_USER` / `DB_PASSWORD`.

### 1C. Ask about the first feature

**Greenfield.** Same question as RazorStar: entity name, fields, any special behaviour. Every greenfield app ships login + dashboard. They still need one CRUD feature.

**Attach (hydra-v3).** The UI does not own new aggregates. It calls published ports. Ask which operator screen to build first:

| Screen | Why | Datastar |
|--------|-----|----------|
| **Campaign trigger + live progress** (recommended) | The thing an operator *does*. Progress is a live view. | SSE patch of the progress panel |
| Registry list | Usage points / devices. Closest to CRUD. | Table fragment search |
| Quarantine triage | Drainable identity failures | Table + "why" |
| Single-meter TOA | Calls `OrchestrationService.requestToaDelivery` | Form POST, then patch task status |

Do not start with a custom metrics dashboard. Grafana has "Hydra TOA". Put a link to `http://localhost:3000` on the operator dashboard and move on.

### 1D. Theme and layout

Same as RazorStar. Defaults live in `assets/`. Offer tweakcn, logo, login background. See [theme-customization.md](references/theme-customization.md).

Ask: *"Sidebar, top nav, or creative (minimal chrome)?"*

| Option | Use |
|--------|------|
| **Sidebar** (default) | Many sections. hydra operator: this. |
| **Top nav** | Few sections |
| **Creative** | Single-purpose / dashboard-led |

### 1E. Confirm the plan

**Greenfield example:**

> *"Here's what I'll set up for **InventoryTracker** (`com.example.inventory`):*
> 1. *Javalin 7 + JTE + Datastar + Basecoat, Java 21, virtual threads*
> 2. *PostgreSQL via Docker (credentials in `.env`)*
> 3. *Session login, bcrypt, seeded admin from `.env`*
> 4. *Dashboard with a summary card*
> 5. *CRUD for **Products** (Name, Price, IsActive)*
> 6. *Navigation: **Sidebar***
>
> *Sound good?*"

**hydra attach example:**

> *"Here's what I'll add to hydra-v3:*
> 1. *New `:hes-ui` Gradle module, package `za.co.ipay.hydra.v3.ui`*
> 2. *Javalin in the same JVM as `SkeletonApp`, port 8080*
> 3. *Leave Prometheus/Grafana on 9464/3000*
> 4. *Stub session (context 11 RBAC is later)*
> 5. *Dashboard + first screen: **campaign trigger + live progress***
> 6. *Sidebar layout*
>
> *The UI module depends on published ports (`registry-api`, `audit-api`, `alarms-api`) and the orchestration service. It does not depend on `*.impl` packages. Sound good?*"

Wait for confirmation.

---

## Phase 2: Scaffold

Work in order. Placeholders: `MyApp` / `myapp` / `pkg`. Substitute everywhere.

### Greenfield steps

1. Gradle Java 21 app + packages. See [project-scaffolding.md](references/project-scaffolding.md).
2. `.env` + Docker Postgres + copy `scripts/start-dev-environment.sh`. See [docker-setup.md](references/docker-setup.md).
3. Copy `assets/` into `src/main/resources/public/`. Tailwind CLI for `tailwind-output.css`.
4. Shared kernel: `Result`, `Clock`, Jdbi, Flyway, SSE helpers. See [architecture-patterns.md](references/architecture-patterns.md) and [datastar-sse.md](references/datastar-sse.md).
5. `App.java` composition root. See [javalin-app.md](references/javalin-app.md).
6. JTE layouts matching the nav choice. See [jte-templates.md](references/jte-templates.md).
7. Login + dashboard. See [login-page.md](references/login-page.md) and [dashboard-page.md](references/dashboard-page.md).

### Attach steps (hydra-v3)

Do **not** run greenfield steps 2 or 7's Identity seed against a new database.

1. Add `:hes-ui` to `settings.gradle`. Plugin `gg.jte.gradle` on that module only.
2. `hes-ui` depends on published leaves + `:orchestration` (the service, no `impl` split yet) + Javalin/JTE/Datastar. Never `:registry` impl, `:mdm` internals, `:audit` impl.
3. Copy assets into `hes-ui/src/main/resources/public/`.
4. `UiServer` (Javalin) constructed in `SkeletonApp`, started next to the existing `MetricsHttpServer`. Default `UI_PORT=8080`.
5. Extend `architecture` ArchUnit tests so `..ui..` may depend on `..registry.api..`, `..audit.api..`, `..alarms.api..`, `..orchestration..`, `..contracts..`, and must not depend on `..registry.impl..`, `..audit.impl..`, `..mdm..`, `..collector..`.
6. Stub auth: a shared operator name from env, or a single-password gate. Do not stand up a users table on Citus for this.
7. Dashboard that reads counts already on the composition root (ingest, quarantine, tasks, campaign progress) plus a Grafana link.

Details: [attach-modular-monolith.md](references/attach-modular-monolith.md).

---

## Phase 3: First run - verify the boilerplate works

**Checkpoint. Do not build the first feature until they have seen the app.**

**Greenfield:**

> *"Boilerplate is ready.*
> 1. `./scripts/start-dev-environment.sh`
> 2. `./gradlew run`
> 3. *Open the URL in the console (http://localhost:8080)*
> 4. *Sign in with `DEV_ADMIN_USERNAME` / `DEV_ADMIN_PASSWORD` from `.env`*
>
> *Tell me when you're in."*

**hydra attach:**

> *"UI is wired into the skeleton.*
> 1. *Start the rig you already use (`compose.rig.yml` or `compose.dev.yml`)*
> 2. `./gradlew :app-skeleton:run`
> 3. *Operator UI: http://localhost:8080*
> 4. *Grafana is still http://localhost:3000 (admin/admin)*
>
> *You should see the dashboard with live counts from the TOA demo loop. Tell me when you're in."*

Wait for confirmation.

---

## Phase 4: Build the first feature

### Greenfield CRUD

```
src/main/java/pkg/features/items/
  Item.java              # record + factory validation
  ItemStore.java         # Jdbi SQL
  ItemRoutes.java        # GET pages, GET fragment, POST create/edit/delete
src/main/jte/items/
  index.jte
  table.jte              # fragment for SSE morph
  create.jte
  edit.jte
  details.jte
src/main/resources/db/migration/
  V002__items.sql
```

Register routes from `App.java`. Add a nav link and a dashboard card. Flyway runs on boot. Ask them to restart and create a row.

See [crud-feature-reference.md](references/crud-feature-reference.md) and [crud-pages.md](references/crud-pages.md).

### hydra attach

The "entity" is not a new table. Routes call `OrchestrationService`, `TargetQuery`, `IdentityResolver`, `CampaignProgressStore` (via the service), `AlarmStore` if needed.

Campaign live view: `data-init="@get('/campaigns/{id}/live')"` opens an SSE stream. A virtual thread reads `campaignProgress` on a short interval and patches the panel when counts change. The UI must **not** subscribe to `SpineBus`. A UI consumer group would steal or duplicate domain events. Read the projection.

After it works, ask them to trigger a campaign (or let `DemoToaLoop` keep ticking) and watch the panel update without a full page load.

---

## Phase 5: Handoff

Greenfield: login, dashboard, one CRUD feature, how to add the next entity (store + routes + jte + Flyway + nav + card).

Attach: dashboard, first operator screen, the Grafana split, the ArchUnit rule, "next screen is another route class against an existing port."

Tailwind watcher, both tracks:

```bash
./tailwindcss -i src/main/resources/public/css/site.css -o src/main/resources/public/css/tailwind-output.css --watch
```

Adjust the path if the module is `hes-ui/`.

---

## Architecture principles

1. **Server-rendered first.** Javalin GET returns a full JTE page. Anchors navigate. The browser owns history.
2. **Datastar for reactivity.** Signals for input and toggles. SSE to patch HTML. Prefer fat morph over fine-grained signal graphs. See the tao in [architecture-patterns.md](references/architecture-patterns.md).
3. **Sealed `Result` over exceptions for expected failure.** Validation, not-found, rule violations. Broken connections still throw.
4. **Feature packages, not a `controllers/` dump.** `features/items/` owns routes, store, and page records. Templates live under `src/main/jte/items/`.
5. **SQL-first.** Jdbi maps to records. No session, no dirty-checking, no lazy load. Citus `ON CONFLICT` and composite keys stay visible.
6. **Composition root.** `App.java` / `SkeletonApp` constructs the graph. Javalin is not an IoC container.
7. **UI is a delivery surface.** In a modular monolith it depends on published language, never another context's internals.
8. **Grafana watches. JTE does.** If the question is "how is the rate changing?", it is not a JtStar page.

## The separation rule

| Concern | Approach |
|---------|----------|
| Forms / navigation | GET page, POST then redirect. Ordinary HTTP. |
| UI reactivity | Datastar signals |
| Realtime / progress | Datastar SSE (`PatchElements` / `PatchSignals`) |
| Numeric time-series | Prometheus + Grafana. Link out. |
| Micro-actions | Optional JSON. Prefer HTML patches. |

The backend drives the frontend. Prefer patching over signals.

## Name substitution reference

| Placeholder | Meaning |
|-------------|--------|
| `MyApp` | Display name, class prefixes (`InventoryTracker`) |
| `myapp` | Docker service, db name (greenfield) |
| `pkg` | Java package (`com.example.inventory`) |
| `Item` / `items` | First feature type / URL segment |

hydra attach substitutes `za.co.ipay.hydra.v3.ui`, module `hes-ui`, and does not create `myapp` Docker names.

## Additional references

- [project-scaffolding.md](references/project-scaffolding.md). Gradle, deps, static files, Tailwind
- [attach-modular-monolith.md](references/attach-modular-monolith.md). hydra-v3 module, ArchUnit, composition root
- [javalin-app.md](references/javalin-app.md). `App.java`, sessions, virtual threads, exception handler
- [jte-templates.md](references/jte-templates.md). Layouts, fragments, page records
- [datastar-sse.md](references/datastar-sse.md). Javalin adapters, patch helpers, live views
- [architecture-patterns.md](references/architecture-patterns.md). Packages, `Result`, Jdbi, Datastar tao
- [docker-setup.md](references/docker-setup.md). Greenfield compose + `.env`
- [login-page.md](references/login-page.md). Session login
- [dashboard-page.md](references/dashboard-page.md). Cards, Grafana link
- [crud-feature-reference.md](references/crud-feature-reference.md). File checklist
- [crud-pages.md](references/crud-pages.md). Index/create/edit/details in JTE
- [ui-component-patterns.md](references/ui-component-patterns.md). Basecoat + Datastar
- [theme-customization.md](references/theme-customization.md). tweakcn into `theme.css`
- [observability.md](references/observability.md). What belongs in Grafana vs the UI
