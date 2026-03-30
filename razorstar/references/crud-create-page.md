# Create Page

Two-column layout with form card and sidebar guidelines. Standard Razor Pages POST with server-side validation.

## Create.cshtml.cs

```csharp
public class CreateModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly ILogger<CreateModel> _logger;

    public CreateModel(IMediator mediator, ILogger<CreateModel> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [BindProperty]
    [Required(ErrorMessage = "Name is required")]
    [StringLength(100, MinimumLength = 2, ErrorMessage = "Name must be 2-100 characters")]
    [Display(Name = "Name")]
    public string Name { get; set; } = string.Empty;

    [BindProperty]
    [Display(Name = "Active")]
    public bool Active { get; set; } = true;

    public List<ErrorDetail>? ErrorDetails { get; private set; } = [];

    public void OnGet() { }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid) return Page();

        var command = new CreateItemCommand(Name, Active);
        var result = await _mediator.Send(command, cancellationToken);

        if (result.IsError)
        {
            ErrorDetails = result.Errors.ToErrorDetails();
            return Page();
        }

        TempData["SuccessMessage"] = $"Item '{result.Value.Name}' created successfully.";
        return RedirectToPage("Details", new { id = result.Value.Id });
    }
}
```

## Create.cshtml

```html
@page
@model CreateModel
@{ ViewData["Title"] = "Create Item"; }

<div data-signals="{
    item: { name: '', active: true, validationErrors: {}, loading: false, showGuidelines: true }
}" style="display: none;"></div>

<!-- Breadcrumb (depth: Dashboard > Items > Create) -->
<nav aria-label="breadcrumb" class="mb-4">
    <ol class="text-muted-foreground flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5">
        <li class="inline-flex items-center gap-1.5"><a href="/" class="hover:text-foreground transition-colors">Dashboard</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><a href="/Items" class="hover:text-foreground transition-colors">Items</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><span class="text-foreground font-normal" aria-current="page">Create</span></li>
    </ol>
</nav>

@if (Model.ErrorDetails is not null && Model.ErrorDetails.Any())
{
    @await Html.PartialAsync("_Message", new MessageViewModel(
        Category: "error", Title: "Error",
        Message: $"{Model.ErrorDetails.Count} error{(Model.ErrorDetails.Count > 1 ? "s" : "")} occurred:",
        Errors: Model.ErrorDetails))
}

<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
    <!-- Main form (8/12) -->
    <div class="lg:col-span-8">
        <form method="post">
            <div class="card">
                <header><h2>Create Item</h2><p>Fill in the details for the new item.</p></header>
                <section class="grid gap-6">
                    <!-- Name field with client-side validation -->
                    <div class="grid gap-2">
                        <label for="name" class="text-sm font-medium">Name <span class="text-destructive">*</span></label>
                        <input type="text" id="name" name="Name" class="input" placeholder="Enter item name"
                               data-bind="item.name"
                               data-on-input="$item.validationErrors.name = $item.name.trim().length < 2 ? 'Name must be at least 2 characters' : ($item.name.length > 100 ? 'Name cannot exceed 100 characters' : '')"
                               data-class="{ 'border-destructive': !!$item.validationErrors.name }" />
                        <p class="text-sm text-destructive" data-show="!!$item.validationErrors.name" data-text="$item.validationErrors.name"></p>
                        <span asp-validation-for="Name" class="text-sm text-destructive"></span>
                    </div>
                    <!-- Active toggle -->
                    <div class="flex items-center gap-3">
                        <div class="switch">
                            <input type="checkbox" id="active" name="Active" value="true" data-bind="item.active" />
                            <label for="active"></label>
                        </div>
                        <label for="active" class="text-sm font-medium">Active</label>
                    </div>
                </section>
                <footer class="flex items-center justify-end gap-3">
                    <a href="/Items" class="btn btn-outline btn-sm text-black dark:text-gray-300">Cancel</a>
                    <button type="submit" class="btn btn-primary btn-ghost"
                            data-attr-disabled="!!$item.validationErrors.name"
                            data-on-click__once__passive="$item.loading = true">
                        Create Item
                    </button>
                </footer>
            </div>
        </form>
    </div>

    <!-- Sidebar (4/12) -->
    <div class="lg:col-span-4 space-y-6">
        <div class="card">
            <header>
                <div class="flex items-center justify-between">
                    <h3>Guidelines</h3>
                    <button type="button" class="btn btn-outline btn-sm text-black dark:text-gray-300"
                            data-on-click__passive="$item.showGuidelines = !$item.showGuidelines">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" data-class="{ 'rotate-180': $item.showGuidelines }"><path d="m6 9 6 6 6-6"/></svg>
                    </button>
                </div>
            </header>
            <section data-show="$item.showGuidelines">
                <ul class="list-disc pl-4 space-y-2 text-sm text-muted-foreground">
                    <li>Name must be unique and 2-100 characters</li>
                    <li>Active items are visible to users</li>
                </ul>
            </section>
        </div>
    </div>
</div>
```

## Key Patterns

- **Signals**: singular namespace (`item`), no change tracking needed
- **Submit disable**: validation errors only — `data-attr-disabled="!!$item.validationErrors.name"`
- **Minimise pattern**: `data-show` on `<section>` only, not the whole card — header and toggle button always visible
- **Footer spacing**: `flex items-center justify-end gap-3` on all `<footer>` elements
- **Success flow**: `TempData["SuccessMessage"]` + `RedirectToPage("Details")`
- **Error flow**: `ErrorDetails` + re-render same page
