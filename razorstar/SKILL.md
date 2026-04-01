---
name: razorstar
description: Build a web application using ASP.NET Razor Pages, EF Core with a PostgreSQL database, Datastar for UI reactivity real-time updates via SSE, and Basecoat UI components for simplified Tailwind CSS. Useful for building server-side rendered web applications, where offline capabilities are not required. Use when the user asks to create a razorstar app, set up a new web app with the RazorStar stack, or add features to an existing RazorStar app. Even if the user just says they want to "build a web app" or "create a CRUD app" or "scaffold a project", consider whether the RazorStar stack is appropriate and offer it.
---

# RazorStar App Builder

A RazorStar app is an ASP.NET Core Razor Pages web application enhanced with **Datastar** for UI reactivity and **Basecoat UI** for component styling. Server-rendered by default, with SSE-powered real-time updates where needed.

This skill guides you through a **conversational workflow** — not just what to build, but how to work with the user through each phase. Follow the phases in order and don't skip the checkpoints.

## Table of Contents

- [Tech Stack](#tech-stack)
- [Bundled Resources](#bundled-resources)
- [Phase 1: Discovery - Gather Requirements Before Writing Code](#phase-1-discovery---gather-requirements-before-writing-code)
- [Phase 2: Scaffold the Application](#phase-2-scaffold-the-application)
- [Phase 3: First Run - Verify the Boilerplate Works](#phase-3-first-run---verify-the-boilerplate-works)
- [Phase 4: Build the First Feature](#phase-4-build-the-first-feature)
- [Phase 5: Handoff](#phase-5-handoff)
- [Architecture Principles](#architecture-principles)
- [The Separation Rule](#the-separation-rule)
- [Name Substitution Reference](#name-substitution-reference)
- [Additional References](#additional-references)

## Tech Stack

| Layer | Technology |
|-------|-----------|
| **UI Framework** | Razor Pages (.NET 10) |
| **Reactivity** | Datastar (html patching, signals, SSE) |
| **Components** | Basecoat UI (Tailwind-based shadcn/ui for non-React stacks) |
| **Styling** | Tailwind CSS v4 (CLI standalone) |
| **ORM** | Entity Framework Core + PostgreSQL |
| **Auth** | ASP.NET Identity API endpoints + EF Core |
| **Error Handling** | ErrorOr (no exceptions for expected failures) |
| **CQRS** | MediatR |
| **Logging** | Serilog + OpenTelemetry |

All frontend libraries are bundled locally for air-gapped environments.

## Bundled Resources

This skill ships with three resource folders — copy files from them during scaffolding:

| Folder | Contents | When to copy |
|--------|----------|-------------|
| `assets/` | CSS (basecoat, tailwind, theme, landing), JS (basecoat, datastar, site), fonts, logo | Step 3 — copy into `wwwroot/` |
| `scripts/` | `start-dev-environment.ps1` — one-command dev startup | Step 2 — copy into project's `scripts/` |
| `references/` | Detailed implementation docs (not copied into the project) | Read as needed during scaffolding |

---

## Phase 1: Discovery - Gather Requirements Before Writing Code

**Do not start scaffolding until you've completed this phase.** The conversation takes 2-3 exchanges and saves significant rework.

### 1A. Ask for the App Name

The app name drives naming everywhere — project files, namespaces, Docker services, database names, page titles, sidebar heading.

Ask: *"What would you like to call your application?"*

Derive all naming variants from their answer:

| Variant | Derivation | Example ("InventoryTracker") |
|---|---|---|
| `MyApp` | PascalCase — project, namespaces, class prefixes, `<title>`, sidebar | `InventoryTracker` |
| `myapp` | lowercase — Docker service/container, Postgres DB/user, network | `inventorytracker` |

Credentials (database password, dev user password) are **never hardcoded** in source files. They live in a `.env` file that is gitignored — see [Step 2](#step-2-create-env-file-and-set-up-docker-postgresql) for details.

### 1B. Ask About the First Feature

Every RazorStar app ships with login + dashboard out of the box. But the user needs at least one CRUD feature for the app to be useful.

Ask: *"What's the first thing you want to manage in this app? For example, 'Products', 'Employees', 'Tickets'. Tell me the entity name and the key fields it should have."*

Capture:
- **Entity name** (e.g., "Product")
- **Key fields** with types (e.g., Name: string, Price: decimal, IsActive: bool)
- **Any special behavior** (e.g., "Products can be archived", "Tickets have a status workflow")

### 1C. Review and Customise Theme & Images

Before scaffolding, advise the user to review and replace the default images and theme in this skill's `assets/` folder:

> *"Before we start building, you may want to customise the look and feel. The skill ships with defaults you can replace:*
>
> - **Logo** (`assets/images/logo.webp`) — Your app logo. Recommended: WebP format, ~200x60px for sidebar display, or square ~128x128px for the login card.
> - **Background image** (`assets/css/landing.css` references `/images/key-visual.jpg`) — Hero/background image for the login page. Recommended: JPEG, 1920x1080px minimum. If no image is available, a CSS gradient fallback is used.
> - **Theme** (`assets/css/theme.css`) — CSS variables for colours, border radii, and spacing. You can generate a custom theme from [tweakcn](https://tweakcn.com) and paste it into `theme.css`.
>
> *Would you like to customise these now, or go with the defaults and tweak later?"*

For step-by-step instructions on pasting a tweakcn theme, see [theme-customization.md](references/theme-customization.md).

### 1D. Choose Navigation Layout

Ask: *"Which navigation layout would you prefer?"*

| Option | Description |
|--------|-------------|
| **Sidebar** (default) | Left panel with collapsible sidebar. Best for apps with many sections or deep navigation. |
| **Top Nav** | Horizontal navigation bar at the top. Clean look for simpler apps with fewer sections. |
| **Creative** | No fixed navigation — just a minimal header with the app name, dark mode toggle, and profile link. Best for single-purpose apps, dashboards, or landing-page-style layouts where navigation is embedded in the page content itself. |

Capture the choice — it determines which `_Layout.cshtml` template to use in Step 6. See [project-scaffolding.md](references/project-scaffolding.md) for all three layout templates.

### 1E. Confirm the Plan

Before writing code, summarize what you'll build and get a thumbs-up:

> *"Here's what I'll set up for **InventoryTracker**:*
> 1. *ASP.NET Razor Pages project with Datastar + Basecoat UI*
> 2. *PostgreSQL via Docker (credentials in `.env` file, gitignored)*
> 3. *Login page with a seeded dev user (credentials in `.env`)*
> 4. *Dashboard with a summary card*
> 5. *Full CRUD for **Products** (Name, Price, IsActive) — Index table with search & pagination, Create, Edit, and Details pages*
> 6. *Navigation: **Sidebar** layout* *(or Top Nav / Creative — per your choice)*
> 7. *Theme: default* *(or custom — per your earlier choice)*
>
> *Sound good, or do you want to adjust anything?"*

Wait for confirmation before proceeding.

---

## Phase 2: Scaffold the Application

Work through these steps in order. All reference files use `MyApp`/`myapp` as placeholders — substitute the user's chosen name everywhere.

### Step 1: Create Project and Install Packages

```powershell
dotnet new webapp -n MyApp --framework net10.0
cd MyApp
```

**Required NuGet packages:**

```powershell
dotnet add package ErrorOr
dotnet add package MediatR
dotnet add package StarFederation.Datastar
dotnet add package Microsoft.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.OpenTelemetry
```

For complete package list with versions, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 2: Create `.env` File and Set Up Docker (PostgreSQL)

#### 2a. Create the `.env` file

Create a `.env` file in the **solution root** (parent of the project folder). This is the **single source of truth** for all development credentials — no secret values are hardcoded anywhere else.

Generate a secure dev user password that meets ASP.NET Identity requirements (at least 6 characters, with uppercase, lowercase, digit, and non-alphanumeric character). Use the `{lowercase}` naming convention for database values.

```
# Dev environment credentials — DO NOT commit (gitignored)
POSTGRES_DB=myapp
POSTGRES_USER=myapp
POSTGRES_PASSWORD=<generate-a-secure-password>
DEV_ADMIN_USERNAME=admin
DEV_ADMIN_PASSWORD=<generate-a-secure-password>
```

Add both `.env` and `db/` to `.gitignore`:
```
# Dev credentials
.env

# PostgreSQL local data
db/
```

#### 2b. Create `docker-compose.yml`

Create in the **solution root** with a PostgreSQL 15 Alpine service that reads credentials from `.env` via variable interpolation. Add health check and named network.

For the complete docker-compose template and placeholder substitution table, see [docker-setup.md](references/docker-setup.md).

Start the database and verify it's healthy:

```powershell
docker compose up -d
docker compose ps
```

#### 2c. Copy the dev startup script

Copy the bundled `scripts/start-dev-environment.ps1` from this skill's `scripts/` folder into the project's `scripts/` folder. Replace `MyApp`/`myapp-db` placeholders with the user's app name. This gives the user a one-command dev startup that checks Docker, starts containers, waits for health, and generates `appsettings.Local.json` from `.env` values. See [project-scaffolding.md](references/project-scaffolding.md) for placeholder details.

#### 2d. Configure appsettings

`appsettings.json` contains non-secret configuration only. The connection string and dev seed credentials are loaded at runtime from `appsettings.Local.json`, which is generated by the startup script from `.env` values and is gitignored.

For complete Docker and appsettings configuration, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 3: Set Up Static Assets

Copy bundled assets from the skill's `assets/` folder into the project's `wwwroot/` — CSS (basecoat, tailwind, theme, landing), JS (basecoat, datastar, site), fonts, and images.

For the complete directory structure, `site.css`, `theme.css`, and Tailwind CLI setup, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 4: Configure Shared Infrastructure

Create the shared foundation classes under `Features/Shared/` and `Shared/`. For the complete file layout, see [shared-infrastructure.md](references/shared-infrastructure.md), which links to:

- [shared-domain.md](references/shared-domain.md) — Base classes, AppDbContext, IClock, Feature DI pattern
- [shared-control-flow.md](references/shared-control-flow.md) — ErrorOr, RazorPageExtensions, GlobalExceptionHandler, UnitOfWork
- [shared-toasts-notifications.md](references/shared-toasts-notifications.md) — Toast/Message models, partials

### Step 5: Configure Program.cs

`Program.cs` registers Datastar, MediatR, EF Core + PostgreSQL, Identity with cookie auth (redirecting to `/Auth/Login`), and Razor Pages with folder-level authorization. In development, it auto-migrates the database and seeds a dev user using credentials from `IConfiguration` (populated from `appsettings.Local.json`, which is generated from `.env` — never hardcoded).

For the complete `Program.cs` template, middleware pipeline order, and per-feature DI registration pattern, see [program-cs.md](references/program-cs.md).

### Step 6: Set Up Layout, View Imports and ViewStart

**`Pages/_ViewImports.cshtml`:**
```html
@using MyApp
@namespace MyApp.Pages
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

**`Pages/_ViewStart.cshtml`:**
```html
@{
    Layout = "_Layout";
}
```

**`_Layout.cshtml`** — use the template matching the user's layout choice from Phase 1 Step 1D:

| Layout | Key Features |
|--------|-------------|
| **Sidebar** (default) | Basecoat sidebar, collapsible nav, header with dark mode toggle + profile |
| **Top Nav** | Horizontal nav bar at top, full-width content |
| **Creative** | Minimal header only (app name, dark mode, profile), no navigation chrome — pages manage their own navigation |

All three layouts share:
- `<head>`: basecoat.all.min.js, datastar.js, basecoat.css, tailwind-output.css, theme.css
- `<body>`: DataStar signal initialization (`antiForgeryToken`, `loading`, `themeMode`, `user`, `currentPage`)
- Header with **dark mode toggle** and **profile link** (username as ghost button)
- Main content area with `@RenderBody()` and footer
- Toast container: `<div id="toaster" class="toaster" data-align="end"></div>`

For all three layout templates, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 7: Create Login and Dashboard Pages

**Login page** — uses `_LandingLayout.cshtml` (no sidebar, centered frosted-glass card). Cookie auth via ASP.NET Identity `SignInManager`.

Files to create:
- `Pages/Shared/_LandingLayout.cshtml` — Minimal centered layout
- `Pages/Auth/Login.cshtml` + `.cshtml.cs` — Login form with DataStar loading state
- `Features/Auth/ViewModels/LoginViewModel.cs` — Form binding model
- `Pages/Index.cshtml` + `.cshtml.cs` — Root `/` redirect to Dashboard

For complete implementations, see [login-page.md](references/login-page.md).

**Dashboard page** — the authenticated home page. Summary card per aggregate with record count + quick-action link. Starts with a single card for the first feature.

Files to create:
- `Pages/Dashboard/Index.cshtml` + `.cshtml.cs` — Summary cards grid

For complete implementations, see [dashboard-page.md](references/dashboard-page.md).

---

## Phase 3: First Run - Verify the Boilerplate Works

**This is a checkpoint. Do not proceed to building features until the user has confirmed the app runs.**

After scaffolding, present the startup steps:

> *"The boilerplate is ready. Here's how to run it:*
>
> 1. *Start the dev environment: `.\scripts\start-dev-environment.ps1`*
> 2. *Create the initial migration: `dotnet ef migrations add InitialCreate`*
> 3. *Run the app: `dotnet run`*
> 4. *Open the URL from the console output*
> 5. *Sign in with the credentials from your `.env` file (`DEV_ADMIN_USERNAME` / `DEV_ADMIN_PASSWORD`)*
>
> *Let me know when you're in and I'll start building the [Entity] feature."*

Optional: For ongoing CSS development, run the Tailwind watcher in a second terminal (`./tailwindcss -i wwwroot/css/site.css -o wwwroot/css/tailwind-output.css --watch`). The initial `tailwind-output.css` was copied from assets, so this is only needed when modifying styles.

The user should see the login page (centered frosted-glass card), then after logging in, the Dashboard with summary cards and navigation matching their layout choice. For visual details, see [login-page.md](references/login-page.md) and [dashboard-page.md](references/dashboard-page.md).

Wait for the user to confirm the app runs before proceeding.

---

## Phase 4: Build the First Feature

Now build the CRUD feature the user described in Phase 1. Follow the feature-based structure:

```
Features/
└── Items/
    ├── Commands/
    │   ├── CreateItemCommand.cs
    │   ├── UpdateItemCommand.cs
    │   └── DeleteItemCommand.cs
    ├── Queries/
    │   ├── GetItemsQuery.cs
    │   └── GetItemByIdQuery.cs
    ├── Models/
    │   └── Item.cs              # Aggregate root + ID + errors + DTOs + repo + EF config
    └── DependencyInjection.cs

Pages/
└── Items/
    ├── Index.cshtml             # Table with SSE fragments
    ├── Index.cshtml.cs
    ├── _ItemsTable.cshtml       # Partial for SSE updates
    ├── Create.cshtml
    ├── Create.cshtml.cs
    ├── Edit.cshtml
    ├── Edit.cshtml.cs
    ├── Details.cshtml
    └── Details.cshtml.cs
```

For the CRUD file checklist and handler summary, see [crud-feature-reference.md](references/crud-feature-reference.md).

Page-specific CRUD references:
- [crud-index-page.md](references/crud-index-page.md) — Table with SSE fragments, search, pagination, inline delete
- [crud-create-page.md](references/crud-create-page.md) — Form with validation, two-column layout, sidebar
- [crud-edit-page.md](references/crud-edit-page.md) — Change tracking, danger zone, delete modal
- [crud-details-page.md](references/crud-details-page.md) — Read-only view, Quick Actions sidebar

After building the feature:
1. Register `AddItemServices()` in `Program.cs`
2. Add the `DbSet<Item>` and `ItemConfiguration` to `AppDbContext`
3. Add a sidebar nav item in `_Layout.cshtml`
4. Update the Dashboard with a summary card and quick-action link
5. **Ask the user to create a migration** for the new entity:
   > *"The [Entity] feature is built. Please create a migration for it:*
   > ```powershell
   > dotnet ef migrations add Add[Entity]Table
   > ```
   > *Then restart the app and it will auto-apply. You should see the [Entity] link in the sidebar — try creating your first record."*

---

## Phase 5: Handoff

Once the first feature is working, summarize what was built and set the user up for independence:

> *"Your **[AppName]** is up and running with:*
> - *Login page with cookie authentication*
> - *Dashboard with summary cards*
> - *Full CRUD for [Entity]: Index (search, pagination), Create, Edit (with change tracking), and Details*
>
> *To add more features, just tell me the entity name and fields — I'll follow the same pattern. Each new feature gets its own folder under `Features/` and `Pages/`, plus a dashboard card and sidebar link.*
>
> *For ongoing development, run the Tailwind watcher in a second terminal:*
> ```powershell
> ./tailwindcss -i wwwroot/css/site.css -o wwwroot/css/tailwind-output.css --watch
> ```"

---

## Architecture Principles

1. **Server-rendered first** — Razor Pages handle data fetching, forms, navigation
2. **Datastar for reactivity** — signals for UI state, SSE for real-time updates
3. **ErrorOr over exceptions** — expected failures return errors, unexpected failures bubble to global handler
4. **Feature-based structure** — each feature has its own Commands/, Queries/, Models/, DependencyInjection.cs
5. **Domain-driven design** — aggregates with factory methods returning `ErrorOr<T>`
6. **CQRS via MediatR** — commands mutate, queries read
7. **Co-locate related types** — aggregate root file contains ID, errors, DTOs, repo interface, EF config

For detailed architecture patterns, see [architecture-patterns.md](references/architecture-patterns.md).

## The Separation Rule

| Concern | Approach |
|---------|----------|
| **Forms** | Razor Pages POST (server-side model binding) |
| **UI reactivity** | DataStar signals (client-side interactivity) |
| **Realtime/progress** | DataStar SSE patching and signals (server-sent events) |
| **Micro-actions** | Optional JSON via DataStar (lightweight updates) |

The backend should drive the frontend. Try not to manage too much state on the frontend! Prefer patching over signals. See the [tao of datastar](references/architecture-patterns.md#the-tao-of-datastar) for best practices.

## Name Substitution Reference

All reference files use `MyApp` (PascalCase) and `myapp` (lowercase) as placeholders. Substitute everywhere — project files, namespaces, Docker services, database names, page titles, sidebar heading. For the complete substitution table, see [project-scaffolding.md](references/project-scaffolding.md#name-substitution).

## Additional References

- [project-scaffolding.md](references/project-scaffolding.md) — dotnet CLI, packages, assets, layout
- [docker-setup.md](references/docker-setup.md) — docker-compose.yml template, placeholder substitution, connection string
- [program-cs.md](references/program-cs.md) — Complete Program.cs template, middleware order, feature DI registration
- [login-page.md](references/login-page.md) — Landing layout, Login form, cookie auth, dev user seed
- [dashboard-page.md](references/dashboard-page.md) — Summary cards, aggregate counts, quick actions
- [architecture-patterns.md](references/architecture-patterns.md) — feature structure, CQRS, DDD, ErrorOr
- [crud-feature-reference.md](references/crud-feature-reference.md) — file checklist + handler summary
- [crud-index-page.md](references/crud-index-page.md) — Index/table with SSE fragments, search, pagination
- [crud-create-page.md](references/crud-create-page.md) — Create form with validation and sidebar
- [crud-edit-page.md](references/crud-edit-page.md) — Edit with change tracking, danger zone, delete
- [crud-details-page.md](references/crud-details-page.md) — Read-only Details view
- [ui-component-patterns.md](references/ui-component-patterns.md) — Basecoat + DataStar UI patterns
- [shared-infrastructure.md](references/shared-infrastructure.md) — file layout overview + links to sub-references
- [shared-domain.md](references/shared-domain.md) — Base classes, AppDbContext, IClock, Feature DI
- [shared-control-flow.md](references/shared-control-flow.md) — ErrorOr, RazorPageExtensions, GlobalExceptionHandler, UnitOfWork
- [shared-toasts-notifications.md](references/shared-toasts-notifications.md) — Toast/Message models, `_Message` and `_Toast` partials