# Dashboard Page

The dashboard is the authenticated landing page. It provides a summary overview of each aggregate in the app with record counts, and quick-access links to the CRUD pages.

## Table of Contents

- [File Checklist](#file-checklist)
- [Design Principles](#design-principles)
- [Index.cshtml.cs](#indexcshtmlcs)
- [Index.cshtml](#indexcshtml)
- [Sidebar Navigation Update](#sidebar-navigation-update)
- [Scaling the Dashboard](#scaling-the-dashboard)

## File Checklist

```
Pages/
└── Dashboard/
    ├── Index.cshtml                 # Dashboard view
    └── Index.cshtml.cs              # Loads summary data via MediatR queries
```

## Design Principles

- One **summary card per aggregate** (e.g., Items, Orders, Users) showing record count and a brief description
- Each card links to the aggregate's Index page
- Cards arranged in a responsive grid
- Data loaded server-side via MediatR queries — no SSE needed for static counts
- Use Basecoat `.card` component for consistent styling
- Adapt card content to the app's domain (the examples below use generic `Items`)

## Index.cshtml.cs

The PageModel loads summary counts for each aggregate using MediatR queries:

```csharp
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;

namespace MyApp.Pages.Dashboard;

public class IndexModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly ILogger<IndexModel> _logger;

    public IndexModel(IMediator mediator, ILogger<IndexModel> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    public int ItemCount { get; set; }
    // Add a count property per aggregate:
    // public int OrderCount { get; set; }
    // public int CustomerCount { get; set; }

    public List<ErrorOr.Error>? ErrorDetails { get; set; }

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        ViewData["Title"] = "Dashboard";

        var loadResult = await LoadDashboardDataAsync(cancellationToken);
        if (loadResult.IsError)
        {
            ErrorDetails = loadResult.Errors;
        }

        return Page();
    }

    private async Task<ErrorOr.ErrorOr<ErrorOr.Success>> LoadDashboardDataAsync(
        CancellationToken cancellationToken)
    {
        // Load counts for each aggregate
        // Replace with actual queries as features are added
        var itemsResult = await _mediator.Send(
            new Features.Items.Queries.GetItemsQuery(
                SearchQuery: null,
                CurrentPage: 1,
                PageSize: 1),
            cancellationToken);

        if (itemsResult.IsError)
        {
            return itemsResult.Errors;
        }

        ItemCount = itemsResult.Value.TotalCount;

        // Repeat for additional aggregates:
        // var ordersResult = await _mediator.Send(new GetOrdersQuery(...), cancellationToken);
        // OrderCount = ordersResult.Value.TotalCount;

        return ErrorOr.Result.Success;
    }
}
```

**Pattern notes:**
- Use the existing paginated list queries with `PageSize: 1` to get counts cheaply, or create dedicated `GetXxxCountQuery` queries if preferred
- `LoadDashboardDataAsync` follows the private helper pattern returning `ErrorOr<Success>`
- Add one count property and one query call per aggregate

## Index.cshtml

```html
@page
@model MyApp.Pages.Dashboard.IndexModel
@{
    ViewData["Title"] = "Dashboard";
}

<!-- Breadcrumb -->
<nav aria-label="breadcrumb" class="mb-4">
    <ol class="text-muted-foreground flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5">
        <li class="inline-flex items-center gap-1.5">
            <span class="text-foreground font-normal" aria-current="page">Dashboard</span>
        </li>
    </ol>
</nav>

<!-- Error Messages -->
@if (Model.ErrorDetails is not null && Model.ErrorDetails.Any())
{
    @await Html.PartialAsync("_Message", new MyApp.Shared.Messages.MessageViewModel(
        Category: "error",
        Title: "Error",
        Message: $"{Model.ErrorDetails.Count} error{(Model.ErrorDetails.Count > 1 ? "s" : "")} occurred loading dashboard data:",
        Errors: Model.ErrorDetails
    ))
}

<!-- Welcome Section -->
<div class="mb-8">
    <h1 class="text-2xl font-bold text-foreground">
        Welcome back, @(User.Identity?.Name ?? "User")
    </h1>
    <p class="text-muted-foreground mt-1">
        Here's an overview of your application.
    </p>
</div>

<!-- Summary Cards Grid -->
<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6 mb-8">

    <!-- Items Card -->
    <a href="/Items" class="group">
        <div class="card hover:shadow-lg transition-shadow">
            <header class="flex items-center justify-between">
                <h3 class="text-sm font-medium text-muted-foreground">Items</h3>
                <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-muted-foreground group-hover:text-primary transition-colors">
                    <rect width="7" height="9" x="3" y="3" rx="1" />
                    <rect width="7" height="5" x="14" y="3" rx="1" />
                    <rect width="7" height="9" x="14" y="12" rx="1" />
                    <rect width="7" height="5" x="3" y="16" rx="1" />
                </svg>
            </header>
            <section>
                <div class="text-3xl font-bold text-foreground">@Model.ItemCount</div>
                <p class="text-sm text-muted-foreground mt-1">
                    Total items in the system
                </p>
            </section>
        </div>
    </a>

    <!-- 
    Repeat this card pattern for each aggregate. Replace:
    - href="/Items" → href="/YourAggregate"
    - Card title, count property, description, and icon
    
    Example additional card:

    <a href="/Orders" class="group">
        <div class="card hover:shadow-lg transition-shadow">
            <header class="flex items-center justify-between">
                <h3 class="text-sm font-medium text-muted-foreground">Orders</h3>
                <svg ...>...</svg>
            </header>
            <section>
                <div class="text-3xl font-bold text-foreground">@Model.OrderCount</div>
                <p class="text-sm text-muted-foreground mt-1">
                    Active orders
                </p>
            </section>
        </div>
    </a>
    -->

</div>

<!-- Quick Actions -->
<div class="card">
    <header>
        <h2>Quick Actions</h2>
    </header>
    <section>
        <div class="flex flex-wrap gap-3">
            <a href="/Items/Create" class="btn btn-primary btn-ghost">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M5 12h14" />
                    <path d="M12 5v14" />
                </svg>
                New Item
            </a>
            <!-- Add a quick-action button per aggregate Create page -->
        </div>
    </section>
</div>
```

## Sidebar Navigation Update

When the Dashboard page exists, the sidebar in `_Layout.cshtml` should mark it as the active page:

```html
<li>
    <a href="/" aria-current="@(ViewData["Title"]?.ToString() == "Dashboard" ? "page" : "false")">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/>
            <polyline points="9 22 9 12 15 12 15 22"/>
        </svg>
        Dashboard
    </a>
</li>
```

Since `Pages/Index.cshtml.cs` redirects `/` to `/Dashboard/Index`, the sidebar link to `/` lands on the dashboard.

## Scaling the Dashboard

As features are added, expand the dashboard:

1. **Add a count property** to the PageModel for each new aggregate
2. **Add a query call** in `LoadDashboardDataAsync`
3. **Add a summary card** in the grid (copy the card pattern)
4. **Add a quick-action link** for the aggregate's Create page
5. **Update the sidebar** with a nav item for the new feature

The dashboard should grow organically with the app — each new CRUD feature gets a card and a quick action.
