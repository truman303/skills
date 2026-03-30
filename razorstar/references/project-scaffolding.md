# Project Scaffolding Reference

> **Placeholder convention:** `MyApp` (PascalCase) and `myapp` (lowercase) are placeholders throughout this file. Replace with the user's chosen app name. See the "Before You Begin" section in [SKILL.md](../SKILL.md) for the full substitution table.

## Table of Contents

- [Create Project](#create-project)
- [Docker Setup (PostgreSQL)](#docker-setup-postgresql)
- [Dev Startup Script](#dev-startup-script)
- [NuGet Packages](#nuget-packages)
- [.csproj Configuration](#csproj-configuration)
- [Static Asset Setup](#static-asset-setup)
- [Program.cs (Complete Template)](#programcs-complete-template)
- [Layout Template (_Layout.cshtml)](#layout-template-_layoutcshtml)
- [Pages/_ViewImports.cshtml](#pages-_viewimportscsshtml)
- [appsettings.json](#appsettingsjson)
- [appsettings.Development.json](#appsettingsdevelopmentjson)

## Create Project

```powershell
dotnet new webapp -n MyApp --framework net10.0
cd MyApp
```

## Docker Setup (PostgreSQL)

Create `docker-compose.yml` in the **solution root** (parent of the project folder):

```yaml
services:
  myapp-db:
    image: postgres:15-alpine
    container_name: myapp-db
    restart: unless-stopped
    environment:
      POSTGRES_DB: myapp
      POSTGRES_USER: myapp
      POSTGRES_PASSWORD: myapp_dev_password
      POSTGRES_INITDB_ARGS: "--encoding=UTF8 --lc-collate=C --lc-ctype=C"
    ports:
      - "5432:5432"
    volumes:
      - ./db/data/postgresql:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U myapp -d myapp"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - myapp-network

networks:
  myapp-network:
    driver: bridge
```

**Start the database:**

```powershell
docker compose up -d
```

**Verify it's healthy:**

```powershell
docker compose ps
```

Add `db/` to `.gitignore` so local Postgres data isn't committed:

```
# PostgreSQL local data
db/
```

## Dev Startup Script

Copy the bundled script from the skill's `scripts/` folder into the project's `scripts/` folder:

```
scripts/start-dev-environment.ps1   ← copy from skill's scripts/start-dev-environment.ps1
```

The script validates Docker, starts the database container, polls the health check until healthy, and prints next steps (including login credentials). It gives the user a one-command dev environment startup.

**After copying, replace placeholders:**
- `MyApp` → PascalCase app name (in the "Next steps" output and banner)
- `myapp-db` → lowercase container name (in the `docker inspect` health check line)

**Switches:**
- `-Force` — stops existing containers and removes volumes before starting
- `-Rebuild` — rebuilds container images from scratch
- `-Logs` — tails container logs after startup

## NuGet Packages

```powershell
# Core
dotnet add package ErrorOr
dotnet add package MediatR
dotnet add package StarFederation.Datastar

# Entity Framework + PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL

# Identity (built-in API endpoints)
dotnet add package Microsoft.AspNetCore.Identity.EntityFrameworkCore

# Logging & Observability
dotnet add package Serilog.AspNetCore
dotnet add package Serilog.Sinks.OpenTelemetry
dotnet add package Serilog.Extensions.Logging
dotnet add package Serilog.Enrichers.Environment
dotnet add package Serilog.Enrichers.Thread

# OpenTelemetry (optional but recommended)
dotnet add package OpenTelemetry
dotnet add package OpenTelemetry.Extensions.Hosting
dotnet add package OpenTelemetry.Instrumentation.AspNetCore
dotnet add package OpenTelemetry.Instrumentation.Http
dotnet add package OpenTelemetry.Instrumentation.EntityFrameworkCore
dotnet add package OpenTelemetry.Exporter.OpenTelemetryProtocol
```

## .csproj Configuration

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="ErrorOr" Version="2.0.1" />
    <PackageReference Include="MediatR" Version="14.1.0" />
    <PackageReference Include="StarFederation.Datastar" Version="1.2.1" />
    <PackageReference Include="Microsoft.EntityFrameworkCore" Version="10.0.5" />
    <PackageReference Include="Microsoft.AspNetCore.Identity.EntityFrameworkCore" Version="10.0.5" />
    <PackageReference Include="Microsoft.EntityFrameworkCore.Design" Version="10.0.5">
      <PrivateAssets>all</PrivateAssets>
      <IncludeAssets>runtime; build; native; contentfiles; analyzers; buildtransitive</IncludeAssets>
    </PackageReference>
    <PackageReference Include="Npgsql.EntityFrameworkCore.PostgreSQL" Version="10.0.1" />
    <PackageReference Include="Serilog.AspNetCore" Version="10.0.0" />
    <PackageReference Include="Serilog.Sinks.OpenTelemetry" Version="4.2.0" />
    <PackageReference Include="Serilog.Extensions.Logging" Version="10.0.0" />
    <PackageReference Include="Serilog.Enrichers.Environment" Version="3.0.1" />
    <PackageReference Include="Serilog.Enrichers.Thread" Version="4.0.0" />
  </ItemGroup>
</Project>
```

## Static Asset Setup

### Directory Structure

```
wwwroot/
├── css/
│   ├── basecoat.css           # Download from basecoat.dev
│   ├── landing.css            # Login/landing page styles
│   ├── site.css               # Entry point
│   ├── tailwind-output.css    # Generated by Tailwind CLI
│   └── theme.css              # CSS variables
├── js/
│   ├── basecoat.all.min.js    # Download from basecoat.dev
│   ├── datastar.js            # Download from data-star.dev
│   └── site.js                # App JS (usually minimal)
├── fonts/                     # Local fonts for air-gapped use
└── images/                    # App images
```

### site.css (Tailwind Entry Point)

```css
@import "tailwindcss";
@import "./basecoat.css";
@import "./theme.css";

/* Sidebar enhancements for Basecoat */
.sidebar .sidebar-content ul > li > a,
.sidebar .sidebar-content ul > li > details > summary {
    @apply flex w-full items-center gap-2 overflow-hidden rounded-md p-2 text-left text-sm outline-hidden transition-colors;
    @apply hover:bg-sidebar-accent hover:text-sidebar-accent-foreground;
    @apply [&[aria-current=page]]:bg-sidebar-accent [&[aria-current=page]]:font-medium [&[aria-current=page]]:text-sidebar-accent-foreground;
    @apply [&>svg]:size-4 [&>svg]:shrink-0;
}

.sidebar .sidebar-content ul ul > li > a {
    @apply text-sidebar-foreground/70 hover:text-sidebar-accent-foreground;
}

.sidebar svg { flex-shrink: 0; }

.sidebar details > summary { list-style: none; }
.sidebar details > summary::-webkit-details-marker { display: none; }
.sidebar details[open] > summary .chevron-icon { transform: rotate(90deg); }
.sidebar details:not([open]) > summary .chevron-icon { transform: rotate(0deg); }

/* Tab enhancements */
.tabs [role="tab"][aria-selected="true"] {
    @apply bg-background text-foreground border-primary;
    @apply dark:bg-primary dark:text-primary-foreground dark:border-primary;
}
.tabs [role="tab"][aria-selected="false"] {
    @apply text-muted-foreground hover:text-foreground;
}
.tabs [role="tab"]:hover { @apply bg-muted; }
.tabs [role="tab"]:focus-visible { @apply outline-2 outline-offset-2 outline-primary; }
```

### theme.css (CSS Variables)

Refer to the theme.css file in the assets folder for the complete list of CSS variables.

### Tailwind CSS v4 Setup (Standalone CLI)

Tailwind v4 uses CSS-based configuration (no `tailwind.config.js`). The `@theme inline` block in `theme.css` bridges CSS variables to Tailwind utilities.

```powershell
# Download standalone Tailwind CLI (for air-gapped use)
# Place in project root or a tools/ directory
# Run watcher:
./tailwindcss -i wwwroot/css/site.css -o wwwroot/css/tailwind-output.css --watch
```

## Program.cs (Complete Template)

```csharp
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using StarFederation.Datastar.DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

// Datastar for SSE-powered UI updates
builder.Services.AddDatastar();

// MediatR for CQRS
builder.Services.AddMediatR(cfg =>
    cfg.RegisterServicesFromAssembly(typeof(Program).Assembly));

// Utilities
builder.Services.AddScoped<IClock, Clock>();
builder.Services.AddScoped<IRazorPartialRenderer, RazorPartialRenderer>();

// EF Core + PostgreSQL
builder.Services.AddDbContext<AppDbContext>(options =>
    options.UseNpgsql(builder.Configuration.GetConnectionString("DefaultConnection")));

// Identity with EF Core stores
builder.Services.AddIdentityApiEndpoints<IdentityUser>()
    .AddEntityFrameworkStores<AppDbContext>();

builder.Services.ConfigureApplicationCookie(options =>
{
    options.LoginPath = "/Auth/Login";
    options.LogoutPath = "/Auth/Logout";
    options.AccessDeniedPath = "/Auth/AccessDenied";
    options.ExpireTimeSpan = TimeSpan.FromHours(8);
    options.SlidingExpiration = true;
});

// Feature services (one AddXxxServices() per feature)
builder.Services.AddItemServices();

// Razor Pages with auth
builder.Services.AddRazorPages(options =>
{
    options.Conventions.AuthorizeFolder("/");
    options.Conventions.AllowAnonymousToPage("/Auth/Login");
    options.Conventions.AllowAnonymousToPage("/Error");
});

builder.Services.AddHttpContextAccessor();

var app = builder.Build();

// Auto-migrate in development
if (app.Environment.IsDevelopment())
{
    using var scope = app.Services.CreateScope();
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    await db.Database.MigrateAsync();

    // Seed dev user
    var userManager = scope.ServiceProvider.GetRequiredService<UserManager<IdentityUser>>();
    if (await userManager.FindByNameAsync("admin") is null)
    {
        var devUser = new IdentityUser { UserName = "admin", Email = "admin@myapp.local" };
        await userManager.CreateAsync(devUser, "Admin123!");
    }
}

// Global exception handler (must be early in pipeline)
app.UseGlobalExceptionHandler();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

// Identity API endpoints
app.MapIdentityApi<IdentityUser>();

app.MapRazorPages().WithStaticAssets();

await app.RunAsync();
```

## Layout Template (_Layout.cshtml)

```html
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>@ViewData["Title"] - MyApp</title>
    <script nonce>
        (() => {
            try {
                const stored = localStorage.getItem('themeMode');
                const isDark = stored ? stored === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
                if (isDark) document.documentElement.classList.add('dark');
                window.initialThemeMode = isDark ? 'dark' : 'light';
            } catch (_) { }
        })();
    </script>
    <script type="module" src="~/js/basecoat.all.min.js" defer></script>
    <script type="module" src="~/js/datastar.js"></script>
    <link rel="stylesheet" href="~/css/basecoat.css" asp-append-version="true" />
    <link rel="stylesheet" href="~/css/tailwind-output.css" asp-append-version="true" />
    <link rel="stylesheet" href="~/css/theme.css" asp-append-version="true" />
</head>

@inject Microsoft.AspNetCore.Antiforgery.IAntiforgery AntiForgery
@{
    var tokens = AntiForgery.GetAndStoreTokens(Context);
}

<body data-signals="{
        antiForgeryToken: '@tokens.RequestToken',
        loading: false,
        themeMode: window.initialThemeMode || 'light',
        user: {
            name: '@(User.Identity?.Name ?? "Guest")',
            isAuthenticated: @(User.Identity?.IsAuthenticated.ToString().ToLower())
        },
        sidebarCollapsed: false,
        currentPage: '@ViewData["Title"]'
    }">

    <!-- Basecoat Sidebar -->
    <aside class="sidebar" data-side="left" aria-hidden="false">
        <nav aria-label="Main navigation">
            <header class="p-8 m-3">
                <h1 class="text-xl font-bold">MyApp</h1>
            </header>
            <section class="scrollbar ml-1">
                <ul>
                    <li>
                        <a href="/" aria-current="@(ViewData["Title"]?.ToString() == "Dashboard" ? "page" : "false")">
                            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>
                            Dashboard
                        </a>
                    </li>
                    <!-- Add nav items per feature -->
                </ul>
            </section>
        </nav>
    </aside>

    <!-- Main Content -->
    <main class="sidebar-content min-h-screen">
        <header class="border-b border-gray-300 dark:border-gray-700 px-6 py-4">
            <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold" data-text="$currentPage">@ViewData["Title"]</h2>
                <!-- Theme toggle, user menu etc. -->
            </div>
        </header>

        <div class="p-6">
            @RenderBody()
        </div>

        <footer class="border-t border-gray-300 dark:border-gray-700 px-6 py-4 text-center text-sm text-gray-500 dark:text-gray-400">
            &copy; @DateTime.Now.Year MyApp
        </footer>
    </main>

    <!-- Toast container for SSE notifications -->
    <div id="toaster" class="toaster" data-align="end"></div>

    <script src="~/js/site.js" asp-append-version="true"></script>
    @await RenderSectionAsync("Scripts", required: false)
</body>
</html>
```

## Pages _ViewImports.cshtml

```html
@using MyApp
@namespace MyApp.Pages
@addTagHelper *, Microsoft.AspNetCore.Mvc.TagHelpers
```

## Pages _Test.cshtml

tbd..

## appsettings.json

```json
{
  "ConnectionStrings": {
    "DefaultConnection": "Host=localhost;Port=5432;Database=myapp;Username=myapp;Password=myapp_dev_password"
  },
  "RunMigrations": true,
  "Logging": {
    "LogLevel": {
      "Default": "Warning",
      "Microsoft.AspNetCore": "Warning",
      "Microsoft.EntityFrameworkCore": "Warning"
    }
  },
  "AllowedHosts": "*"
}
```

## appsettings.Development.json

```json
{
  "DetailedErrors": true,
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  }
}
```
