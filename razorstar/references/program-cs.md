# Program.cs Reference

> **Placeholder convention:** `MyApp` (PascalCase) and `myapp` (lowercase) are placeholders. Replace with the user's chosen app name. See the Name Substitution table in [SKILL.md](../SKILL.md).

## Complete Program.cs Template

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

## Key Registrations Summary

| Registration | Purpose |
|---|---|
| `AddDatastar()` | Datastar SSE helpers |
| `AddMediatR(...)` | CQRS command/query dispatching |
| `AddDbContext<AppDbContext>(...)` | EF Core with PostgreSQL via connection string |
| `AddIdentityApiEndpoints<IdentityUser>()` | ASP.NET Identity with EF stores |
| `ConfigureApplicationCookie(...)` | Cookie auth redirecting to `/Auth/Login` |
| `AddRazorPages(...)` | Razor Pages with folder-level auth (all pages require login except Login and Error) |
| `AddItemServices()` | Feature-specific DI — add one `AddXxxServices()` call per feature |

## Middleware Pipeline Order

The order matters — authentication and authorization must come after routing:

1. `UseGlobalExceptionHandler()` — catches unhandled exceptions
2. `UseHttpsRedirection()`
3. `UseStaticFiles()`
4. `UseRouting()`
5. `UseAuthentication()`
6. `UseAuthorization()`
7. `MapIdentityApi<IdentityUser>()` — exposes `/register`, `/login`, etc.
8. `MapRazorPages().WithStaticAssets()`

## Dev User Seeding

On startup in Development mode, the app:
1. Auto-applies pending EF migrations
2. Seeds a dev user: **admin** / **Admin123!** (email: `admin@myapp.local`)

Replace `myapp.local` in the email with the lowercase app name: `admin@{lowercase}.local`.

## Adding a New Feature

When the user adds a new feature (e.g., Products), add the DI registration:

```csharp
builder.Services.AddProductServices();
```

Place it alongside the other `AddXxxServices()` calls.
