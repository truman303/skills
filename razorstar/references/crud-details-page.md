# Details Page

Read-only view with two-column layout. Quick Actions sidebar for navigation. No form submission, no DataStar signals needed beyond basic state.

## Details.cshtml.cs

```csharp
public class DetailsModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly ILogger<DetailsModel> _logger;

    public DetailsModel(IMediator mediator, ILogger<DetailsModel> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public string Id { get; set; } = string.Empty;

    public string Name { get; set; } = string.Empty;
    public bool Active { get; set; }
    public string CreatedBy { get; set; } = string.Empty;
    public DateTimeOffset CreatedTs { get; set; }
    public DateTimeOffset UpdatedTs { get; set; }

    public List<ErrorDetail>? ErrorDetails { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        var result = await LoadItemAsync(cancellationToken);
        if (result.IsError)
            ErrorDetails = result.Errors.ToErrorDetails();
        return Page();
    }

    private async Task<ErrorOr<Success>> LoadItemAsync(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new GetItemByIdQuery(Id), cancellationToken);
        if (result.IsError) return result.Errors;

        var item = result.Value;
        Name = item.Name;
        Active = item.Active;
        CreatedBy = item.CreatedBy;
        CreatedTs = item.CreatedTs;
        UpdatedTs = item.UpdatedTs;
        return Result.Success;
    }
}
```

## Details.cshtml

```html
@page "{id}"
@model DetailsModel
@{ ViewData["Title"] = Model.Name; }

<!-- Breadcrumb (depth: Dashboard > Items > ItemName) -->
<nav aria-label="breadcrumb" class="mb-4">
    <ol class="text-muted-foreground flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5">
        <li class="inline-flex items-center gap-1.5"><a href="/" class="hover:text-foreground transition-colors">Dashboard</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><a href="/Items" class="hover:text-foreground transition-colors">Items</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><span class="text-foreground font-normal" aria-current="page">@Model.Name</span></li>
    </ol>
</nav>

<!-- 1. TempData success -->
@if (TempData["SuccessMessage"] is not null)
{
    @await Html.PartialAsync("_Message", new MessageViewModel(
        Category: "success", Title: "Success",
        Message: TempData["SuccessMessage"]!.ToString()!,
        InfoMessage: TempData["InfoMessage"]?.ToString()
    ))
}

<!-- 2. Full page errors -->
@if (Model.ErrorDetails is not null && Model.ErrorDetails.Any())
{
    @await Html.PartialAsync("_Message", new MessageViewModel(
        Category: "error", Title: "Error",
        Message: $"{Model.ErrorDetails.Count} error{(Model.ErrorDetails.Count > 1 ? "s" : "")} occurred:",
        Errors: Model.ErrorDetails
    ))
}

<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
    <!-- Main content (8/12) -->
    <div class="lg:col-span-8">
        <div class="card">
            <header>
                <div class="flex items-center justify-between">
                    <div>
                        <h2>@Model.Name</h2>
                        <p>Item details</p>
                    </div>
                    <span class="badge-outline @(Model.Active ? "bg-accent text-accent-foreground" : "bg-muted text-muted-foreground")">
                        @(Model.Active ? "Active" : "Inactive")
                    </span>
                </div>
            </header>
            <section>
                <dl class="grid grid-cols-1 sm:grid-cols-2 gap-4">
                    <div>
                        <dt class="text-sm font-medium text-muted-foreground">Name</dt>
                        <dd class="mt-1">@Model.Name</dd>
                    </div>
                    <div>
                        <dt class="text-sm font-medium text-muted-foreground">Status</dt>
                        <dd class="mt-1">@(Model.Active ? "Active" : "Inactive")</dd>
                    </div>
                    <div>
                        <dt class="text-sm font-medium text-muted-foreground">Created</dt>
                        <dd class="mt-1">@Model.CreatedTs.ToString("MMM d, yyyy 'at' h:mm tt")</dd>
                    </div>
                    <div>
                        <dt class="text-sm font-medium text-muted-foreground">Last Updated</dt>
                        <dd class="mt-1">@Model.UpdatedTs.ToString("MMM d, yyyy 'at' h:mm tt")</dd>
                    </div>
                </dl>
            </section>
        </div>
    </div>

    <!-- Sidebar (4/12) — Quick Actions -->
    <div class="lg:col-span-4 space-y-6">
        <div class="card">
            <header><h3>Quick Actions</h3></header>
            <section class="grid gap-3">
                <a asp-page="Edit" asp-route-id="@Model.Id"
                   class="btn btn-outline btn-sm text-foreground w-full justify-start">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/></svg>
                    Edit Item
                </a>
                <a asp-page="Index"
                   class="btn btn-outline btn-sm text-foreground w-full justify-start">
                    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
                    Back to All Items
                </a>
            </section>
        </div>

        <!-- Statistics/metadata card -->
        <div class="card">
            <header><h3>Statistics</h3></header>
            <section>
                <dl class="grid gap-3 text-sm">
                    <div class="flex justify-between">
                        <dt class="text-muted-foreground">Created by</dt>
                        <dd>@Model.CreatedBy</dd>
                    </div>
                    <div class="flex justify-between">
                        <dt class="text-muted-foreground">Created</dt>
                        <dd>@Model.CreatedTs.ToString("MMM d, yyyy")</dd>
                    </div>
                    <div class="flex justify-between">
                        <dt class="text-muted-foreground">Last modified</dt>
                        <dd>@Model.UpdatedTs.ToString("MMM d, yyyy")</dd>
                    </div>
                </dl>
            </section>
        </div>
    </div>
</div>
```

## Key Patterns

- **Read-only** — no forms, no DataStar signals needed
- **Only secondary buttons** — all actions use `btn btn-outline btn-sm text-foreground`
- **Quick Actions sidebar** — links to Edit and Back to Index
- **Statistics sidebar** — metadata like created by, dates
- **Breadcrumb depth**: Dashboard > Items > ItemName (3 levels)
- **Success messages**: TempData from Create/Edit redirects
