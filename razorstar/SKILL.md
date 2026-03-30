---
name: razorstar
description: Build a web application using ASP.NET Razor Pages, EF Core with a PostgreSQL database, Datastar for UI reactivity real-time updates via SSE, and Basecoat UI components for simplified Tailwind CSS. Useful for building server-side rendered web applications, where offline capabilities are not required. Use when the user asks to create a razorstar app, set up a new web app with the RazorStar stack, or add features to an existing RazorStar app. Even if the user just says they want to "build a web app" or "create a CRUD app" or "scaffold a project", consider whether the RazorStar stack is appropriate and offer it.
---

# RazorStar App Builder

A RazorStar app is an ASP.NET Core Razor Pages web application enhanced with **Datastar** for UI reactivity and **Basecoat UI** for component styling. Server-rendered by default, with SSE-powered real-time updates where needed.

> **Important:** The skill is highly opinionated and assumes the user is building acccording to the general templates in the references folder. If the user wants to build something that is not a CRUD app, or something that is not a server-side rendered web application, or something that is not a RazorStar app, then the skill is not appropriate and you should not use it.

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
| `myapp_dev_password` | lowercase + `_dev_password` — dev Postgres password | `inventorytracker_dev_password` |

### 1B. Ask About the First Feature

Every RazorStar app ships with login + dashboard out of the box. But the user needs at least one CRUD feature for the app to be useful.

Ask: *"What's the first thing you want to manage in this app? For example, 'Products', 'Employees', 'Tickets'. Tell me the entity name and the key fields it should have."*

Capture:
- **Entity name** (e.g., "Product")
- **Key fields** with types (e.g., Name: string, Price: decimal, IsActive: bool)
- **Any special behavior** (e.g., "Products can be archived", "Tickets have a status workflow")

### 1C. Confirm the Plan

Before writing code, summarize what you'll build and get a thumbs-up:

> *"Here's what I'll set up for **InventoryTracker**:*
> 1. *ASP.NET Razor Pages project with Datastar + Basecoat UI*
> 2. *PostgreSQL via Docker*
> 3. *Login page with dev credentials (admin / Admin123!)*
> 4. *Dashboard with a summary card*
> 5. *Full CRUD for **Products** (Name, Price, IsActive) — Index table with search & pagination, Create, Edit, and Details pages*
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

### Step 2: Set Up Docker (PostgreSQL)

Create `docker-compose.yml` in the **solution root** (parent of the project folder) with a PostgreSQL 15 Alpine service, health check, and named network. Add `db/` to `.gitignore`.

For the complete docker-compose template and placeholder substitution table, see [docker-setup.md](references/docker-setup.md).

Start the database and verify it's healthy:

```powershell
docker compose up -d
docker compose ps
```

Also copy the bundled `scripts/start-dev-environment.ps1` from this skill's `scripts/` folder into the project's `scripts/` folder. Replace `MyApp`/`myapp-db` placeholders with the user's app name. This gives the user a one-command dev startup that checks Docker, starts containers, waits for health, and prints login credentials. See [project-scaffolding.md](references/project-scaffolding.md) for placeholder details.

The matching connection string in `appsettings.json`:

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=myapp;Username=myapp;Password=myapp_dev_password"
  }
}
```

For complete Docker and appsettings configuration, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 3: Set Up Static Assets

Copy bundled assets from the skill's `assets/` folder into the project's `wwwroot/`:

```
wwwroot/
├── css/
│   ├── basecoat.css           # Basecoat component styles
│   ├── landing.css            # Login/landing page styles
│   ├── site.css               # Entry point (imports tailwind, basecoat, theme)
│   ├── tailwind-output.css    # Generated by Tailwind CLI (copy initial version)
│   └── theme.css              # CSS variables for theming
├── js/
│   ├── basecoat.all.min.js    # Basecoat component JS
│   ├── datastar.js            # Datastar library
│   └── site.js                # App-specific JS (usually minimal)
├── fonts/                     # Local fonts for air-gapped use
│   ├── barlow/barlow-v13-latin-regular.woff2
│   ├── poppins/poppins-v24-latin-regular.woff2
│   ├── lora/lora-v37-latin-regular.woff2
│   └── fira-code/fira-code-v27-latin-regular.woff2
└── images/
    └── logo.webp
```

For the complete `site.css`, `theme.css`, and Tailwind CLI setup, see [project-scaffolding.md](references/project-scaffolding.md).

### Step 4: Configure Shared Infrastructure

Create the shared foundation classes under `Features/Shared/` and `Shared/`:

```
Features/
└── Shared/
    ├── Database/
    │   ├── AppDbContext.cs
    │   ├── IUnitOfWork.cs
    │   └── UnitOfWork.cs
    ├── Exceptions/
    │   └── GlobalExceptionHandlerMiddleware.cs
    ├── Extensions/
    │   └── RazorPageExtensions.cs
    └── Models/
        ├── Entity.cs
        ├── AggregateRoot.cs
        ├── ValueObject.cs
        ├── IDomainEvent.cs
        └── IHasDomainEvents.cs

Shared/
├── Clocks/
│   └── IClock.cs
├── Errors/
│   ├── ErrorDetail.cs
│   └── ErrorOrExtensions.cs
├── Messages/
│   └── MessageViewModel.cs
└── Toasts/
    ├── ToastModel.cs
    ├── ToastViewModel.cs
    └── ToasterConfiguration.cs

Pages/Shared/
├── _Message.cshtml
└── _Toast.cshtml
```

For complete implementations, see:
- [shared-domain.md](references/shared-domain.md) — Base classes, AppDbContext, IClock, Feature DI pattern
- [shared-control-flow.md](references/shared-control-flow.md) — ErrorOr, RazorPageExtensions, GlobalExceptionHandler, UnitOfWork
- [shared-toasts-notifications.md](references/shared-toasts-notifications.md) — Toast/Message models, partials
- [shared-infrastructure.md](references/shared-infrastructure.md) — File layout overview + links

### Step 5: Configure Program.cs

`Program.cs` registers Datastar, MediatR, EF Core + PostgreSQL, Identity with cookie auth (redirecting to `/Auth/Login`), and Razor Pages with folder-level authorization. In development, it auto-migrates the database and seeds a dev user (**admin** / **Admin123!**).

For the complete `Program.cs` template, middleware pipeline order, and per-feature DI registration pattern, see [program-cs.md](references/program-cs.md).

### Step 6: Set Up Layout and View Imports

**`Pages/_ViewImports.cshtml`:**
```html
@using MyApp
@namespace MyApp.Pages
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

**`_Layout.cshtml`** must include:
- `<head>`: basecoat.all.min.js, datastar.js, basecoat.css, tailwind-output.css, theme.css
- `<body>`: DataStar signal initialization (`antiForgeryToken`, `loading`, `themeMode`, `user`, `sidebarCollapsed`, `currentPage`)
- Basecoat sidebar with navigation
- Main content area with header, `@RenderBody()`, and footer
- Toast container: `<div id="toaster" class="toaster" data-align="end"></div>`

For the complete layout template, see [project-scaffolding.md](references/project-scaffolding.md).

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

### What needs to happen before `dotnet run`

1. **Start the dev environment** — use the startup script from Step 2, which checks Docker, starts the PostgreSQL container, and waits for it to be healthy:
   ```powershell
   .\scripts\start-dev-environment.ps1
   ```
   Or manually: `docker compose up -d && docker compose ps` (should show `myapp-db` as "healthy").

2. **Ask the user to create the initial migration** — the app auto-migrates on startup, but the migration must exist first:
   > *"The scaffolding is complete. Before we run the app, please create the initial database migration:*
   > ```powershell
   > dotnet ef migrations add InitialCreate
   > ```
   > *Let me know when it's ready."*

3. **Tailwind CSS** — the `tailwind-output.css` file was copied from assets for the initial run. For ongoing development, the user will want to run the Tailwind watcher in a second terminal:
   ```powershell
   ./tailwindcss -i wwwroot/css/site.css -o wwwroot/css/tailwind-output.css --watch
   ```

### Start the app

Once the migration is created:

```powershell
dotnet run
```

The app will:
1. Auto-apply the migration (creates Identity tables in PostgreSQL)
2. Seed a dev user: **admin** / **Admin123!**
3. Start listening (typically `https://localhost:5001` or the port shown in console output)

### What the user sees

**Login page** (`/Auth/Login` — all pages redirect here until authenticated):
- A centered card over a background (gradient or image) with frosted-glass styling
- The app logo and name at the top
- Username and password fields with icons
- A "Log In" button with loading spinner on click

**After logging in with admin / Admin123!:**
- **Dashboard** (`/Dashboard/Index`) — a welcome message ("Welcome back, admin"), a summary card grid (empty counts initially since no features have data yet), and a Quick Actions section
- **Sidebar** on the left with the app name and a Dashboard link
- **Header** showing the current page title
- **Footer** with copyright

### Tell the user what to expect

After scaffolding, give the user clear instructions:

> *"The boilerplate is ready. Here's how to run it:*
>
> 1. *Start the dev environment: `.\scripts\start-dev-environment.ps1`  (checks Docker, starts Postgres, waits for health)*
> 2. *Create the initial migration: `dotnet ef migrations add InitialCreate`*
> 3. *Run the app: `dotnet run`*
> 4. *Open the URL from the console output (e.g., `https://localhost:5001`)*
> 5. *You'll see the login page — sign in with **admin** / **Admin123!***
> 6. *After login, you'll land on the Dashboard*
>
> *Let me know when you're in and I'll start building the [Entity] feature."*

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

All reference files use `MyApp` (PascalCase) and `myapp` (lowercase) as placeholders. Substitute everywhere:

| File / Context | What to replace |
|---|---|
| `dotnet new webapp -n MyApp` | Project name |
| `docker-compose.yml` | Service name, container name, POSTGRES_DB, POSTGRES_USER, password, healthcheck, network |
| `appsettings.json` | Connection string (Database, Username, Password) |
| `_Layout.cshtml` | `<title>`, sidebar `<h1>`, footer `&copy;` |
| `_ViewImports.cshtml` | `@using MyApp`, `@namespace MyApp.Pages` |
| All `namespace` / `using` declarations | `MyApp.Shared.*`, `MyApp.Features.*`, `MyApp.Pages.*` |
| `Program.cs` | Implicit via namespace |
| `.csproj` | Project file name |

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

## Gotchas

- The system uses DateTimeOffset for all genuine date time values. Where only a date is needed, use `DateOnly` instead of `DateTime`. This is to avoid the issue of DateTime being Kind=Unspecified on a specific input DateTime field.
