# Edit Page

Extends Create page patterns with change tracking, unsaved changes warning, danger zone, and delete modal.

## Edit.cshtml.cs

```csharp
public class EditModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly ILogger<EditModel> _logger;

    public EditModel(IMediator mediator, ILogger<EditModel> logger)
    {
        _mediator = mediator;
        _logger = logger;
    }

    [BindProperty(SupportsGet = true)]
    public string Id { get; set; } = string.Empty;

    [BindProperty]
    [Required(ErrorMessage = "Name is required")]
    [StringLength(100, MinimumLength = 2)]
    public string Name { get; set; } = string.Empty;

    [BindProperty]
    public bool Active { get; set; } = true;

    public string CreatedBy { get; set; } = string.Empty;
    public DateTimeOffset CreatedTs { get; set; }
    public DateTimeOffset UpdatedTs { get; set; }

    public List<ErrorDetail>? ErrorDetails { get; private set; } = [];

    public async Task<IActionResult> OnGetAsync(CancellationToken cancellationToken)
    {
        var result = await LoadItemAsync(cancellationToken);
        if (result.IsError)
        {
            ErrorDetails = result.Errors.ToErrorDetails();
        }
        return Page();
    }

    public async Task<IActionResult> OnPostAsync(CancellationToken cancellationToken)
    {
        if (!ModelState.IsValid)
        {
            await LoadItemAsync(cancellationToken);
            return Page();
        }

        var command = new UpdateItemCommand(Id, Name, Active);
        var result = await _mediator.Send(command, cancellationToken);

        if (result.IsError)
        {
            ErrorDetails = result.Errors.ToErrorDetails();
            await LoadItemAsync(cancellationToken);
            return Page();
        }

        TempData["SuccessMessage"] = $"Item '{result.Value.Name}' updated successfully.";
        return RedirectToPage("Details", new { id = Id });
    }

    public async Task<IActionResult> OnPostDeleteAsync(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new DeleteItemCommand(Id), cancellationToken);
        if (result.IsError)
        {
            ErrorDetails = result.Errors.ToErrorDetails();
            await LoadItemAsync(cancellationToken);
            return Page();
        }

        TempData["SuccessMessage"] = $"Item '{Name}' deleted successfully.";
        return RedirectToPage("Index");
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

## Edit.cshtml (Complete Template)

```html
@page "{id}"
@model EditModel
@{ ViewData["Title"] = "Edit " + Model.Name; }

<!-- Signal initialization with original* baselines for change tracking -->
<div data-signals="{
    item: {
        name: '@Html.Raw(Model.Name?.Replace("'", "\\'"))',
        active: @Model.Active.ToString().ToLower(),
        validationErrors: {},
        loading: false,
        hasUnsavedChanges: false,
        showEditGuidelines: true,
        showDeleteModal: false,
        showDangerZone: false,
        deleteConfirmText: '',
        originalName: '@Html.Raw(Model.Name?.Replace("'", "\\'"))',
        originalActive: @Model.Active.ToString().ToLower()
    }
}" style="display: none;"></div>

<!-- Breadcrumb (depth: Dashboard > Items > ItemName > Edit) -->
<nav aria-label="breadcrumb" class="mb-4">
    <ol class="text-muted-foreground flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5">
        <li class="inline-flex items-center gap-1.5"><a href="/" class="hover:text-foreground transition-colors">Dashboard</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><a href="/Items" class="hover:text-foreground transition-colors">Items</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><a asp-page="Details" asp-route-id="@Model.Id" class="hover:text-foreground transition-colors">@Model.Name</a></li>
        <li><svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg></li>
        <li class="inline-flex items-center gap-1.5"><span class="text-foreground font-normal" aria-current="page">Edit</span></li>
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
            <input type="hidden" name="Id" value="@Model.Id" />
            <div class="card">
                <header><h2>Edit Item</h2><p>Update the item details below.</p></header>
                <section class="grid gap-6">
                    <!-- Name field with client-side validation -->
                    <div class="grid gap-2">
                        <label for="name" class="text-sm font-medium">Name <span class="text-destructive">*</span></label>
                        <input type="text" id="name" name="Name" class="input" placeholder="Enter item name"
                               value="@Model.Name"
                               data-bind="item.name"
                               data-on-input="
                                   $item.validationErrors.name = $item.name.trim().length < 2 ? 'Name must be at least 2 characters' : ($item.name.length > 100 ? 'Name cannot exceed 100 characters' : '');
                                   $item.hasUnsavedChanges = ($item.name !== $item.originalName) || ($item.active !== $item.originalActive)"
                               data-class="{ 'border-destructive': !!$item.validationErrors.name }" />
                        <p class="text-sm text-destructive" data-show="!!$item.validationErrors.name" data-text="$item.validationErrors.name"></p>
                        <span asp-validation-for="Name" class="text-sm text-destructive"></span>
                    </div>
                    <!-- Active toggle -->
                    <div class="flex items-center gap-3">
                        <div class="switch">
                            <input type="checkbox" id="active" name="Active" value="true"
                                   @(Model.Active ? "checked" : "")
                                   data-bind="item.active"
                                   data-on-change="$item.hasUnsavedChanges = ($item.name !== $item.originalName) || ($item.active !== $item.originalActive)" />
                            <label for="active"></label>
                        </div>
                        <label for="active" class="text-sm font-medium">Active</label>
                    </div>
                </section>
                <footer class="flex items-center justify-end gap-3">
                    <div data-show="$item.hasUnsavedChanges" class="mr-auto p-2 bg-amber-50 dark:bg-amber-950/30 border border-amber-200 dark:border-amber-800 rounded-lg">
                        <p class="text-sm text-amber-800 dark:text-amber-200 flex items-center">You have unsaved changes</p>
                    </div>
                    <a asp-page="Details" asp-route-id="@Model.Id" class="btn btn-outline btn-sm text-foreground">Cancel</a>
                    <button type="submit" class="btn btn-primary btn-ghost"
                            data-attr-disabled="!!$item.validationErrors.name || !$item.hasUnsavedChanges"
                            data-on-click__once__passive="$item.loading = true">
                        Save Changes
                    </button>
                </footer>
            </div>
        </form>

        <!-- Danger Zone (collapsible) -->
        <div class="card border-red-200 dark:border-red-900 mt-6">
            <header>
                <div class="flex items-center justify-between">
                    <h3 class="text-red-600">Danger Zone</h3>
                    <button type="button" class="btn btn-outline btn-sm text-foreground"
                            data-on-click__passive="$item.showDangerZone = !$item.showDangerZone">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" data-class="{ 'rotate-180': $item.showDangerZone }"><path d="m6 9 6 6 6-6"/></svg>
                    </button>
                </div>
            </header>
            <section data-show="$item.showDangerZone">
                <p class="text-sm text-muted-foreground mb-4">Permanently delete this item. This cannot be undone.</p>
                <button type="button" class="btn-destructive"
                        data-on-click__passive="$item.showDeleteModal = true">
                    Delete Item
                </button>
            </section>
        </div>
    </div>

    <!-- Sidebar (4/12) -->
    <div class="lg:col-span-4 space-y-6">
        <!-- Guidelines (minimisable — header always visible) -->
        <div class="card">
            <header>
                <div class="flex items-center justify-between">
                    <h3>Guidelines</h3>
                    <button type="button" class="btn btn-outline btn-sm text-foreground"
                            data-on-click__passive="$item.showEditGuidelines = !$item.showEditGuidelines">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" data-class="{ 'rotate-180': $item.showEditGuidelines }"><path d="m6 9 6 6 6-6"/></svg>
                    </button>
                </div>
            </header>
            <section data-show="$item.showEditGuidelines">
                <ul class="list-disc pl-4 space-y-2 text-sm text-muted-foreground">
                    <li>Name must be unique and 2-100 characters</li>
                    <li>Changes are tracked — the Save button enables when you modify a field</li>
                    <li>Use the Danger Zone at the bottom to permanently delete</li>
                </ul>
            </section>
        </div>

        <!-- Statistics card -->
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

<!-- Delete Confirmation Modal -->
<dialog id="delete-dialog" class="dialog w-full sm:max-w-md"
        data-show="$item.showDeleteModal"
        data-on-click="if (evt.target === el) $item.showDeleteModal = false">
    <article>
        <header>
            <h2 class="text-red-600">Delete item</h2>
            <p>This action cannot be undone.</p>
        </header>
        <section>
            <div class="grid gap-2">
                <label class="text-sm font-medium">
                    Type <strong>@Model.Name</strong> to confirm
                </label>
                <input type="text" class="input" placeholder="Type name to confirm"
                       data-bind="item.deleteConfirmText"
                       data-class="{ 'border-destructive': $item.deleteConfirmText && $item.deleteConfirmText !== '@Model.Name' }" />
            </div>
        </section>
        <footer class="flex items-center justify-end gap-3">
            <button type="button" class="btn btn-outline btn-sm text-foreground"
                    data-on-click__passive="$item.showDeleteModal = false; $item.deleteConfirmText = ''">
                Cancel
            </button>
            <form method="post" asp-page-handler="Delete">
                <input type="hidden" name="Id" value="@Model.Id" />
                <button type="submit" class="btn btn-destructive"
                        data-attr-disabled="$item.deleteConfirmText !== '@Model.Name'">
                    Delete Item
                </button>
            </form>
        </footer>
    </article>
</dialog>
```

## Key Patterns

- **`value` attributes on inputs**: Always include `value="@Model.PropertyName"` alongside `data-bind` so server-rendered HTML has values immediately, even before DataStar initialises
- **`checked` attribute on toggles**: Use `@(Model.Active ? "checked" : "")` alongside `data-bind`

## Snippet Reference

The complete template above includes the Danger Zone and Delete Modal inline. Below are the isolated snippets for reference if adapting to a different layout.

### Danger Zone (Collapsible)

The `data-show` is on the `<section>` only — the header with the toggle button always remains visible:

```html
<div class="card border-red-200 dark:border-red-900 mt-6">
    <header>
        <div class="flex items-center justify-between">
            <h3 class="text-red-600">Danger Zone</h3>
            <button type="button" class="btn btn-outline btn-sm text-foreground"
                    data-on-click__passive="$item.showDangerZone = !$item.showDangerZone">
                <svg data-class="{ 'rotate-180': $item.showDangerZone }"><!-- chevron --></svg>
            </button>
        </div>
    </header>
    <section data-show="$item.showDangerZone">
        <p class="text-sm text-muted-foreground mb-4">Permanently delete this item. This cannot be undone.</p>
        <button type="button" class="btn-destructive"
                data-on-click__passive="$item.showDeleteModal = true">
            Delete Item
        </button>
    </section>
</div>
```

### Delete Confirmation Modal

```html
<dialog id="delete-dialog" class="dialog w-full sm:max-w-md"
        data-show="$item.showDeleteModal"
        data-on-click="if (evt.target === el) $item.showDeleteModal = false">
    <article>
        <header>
            <h2 class="text-red-600">Delete item</h2>
            <p>This action cannot be undone.</p>
        </header>
        <section>
            <div class="grid gap-2">
                <label class="text-sm font-medium">
                    Type <strong>@Model.Name</strong> to confirm
                </label>
                <input type="text" class="input" placeholder="Type name to confirm"
                       data-bind="item.deleteConfirmText"
                       data-class="{ 'border-destructive': $item.deleteConfirmText && $item.deleteConfirmText !== '@Model.Name' }" />
            </div>
        </section>
        <footer class="flex items-center justify-end gap-3">
            <button type="button" class="btn btn-outline btn-sm text-foreground"
                    data-on-click__passive="$item.showDeleteModal = false; $item.deleteConfirmText = ''">
                Cancel
            </button>
            <form method="post" asp-page-handler="Delete">
                <input type="hidden" name="Id" value="@Model.Id" />
                <button type="submit" class="btn btn-destructive"
                        data-attr-disabled="$item.deleteConfirmText !== '@Model.Name'">
                    Delete Item
                </button>
            </form>
        </footer>
    </article>
</dialog>
```

## Summary

- **Signals**: singular namespace (`item`) with `original*` baselines and `hasUnsavedChanges`
- **`value` attributes**: Always set `value="@Model.PropertyName"` on inputs so server-rendered HTML shows existing values before DataStar initialises
- **Submit disable**: validation errors + no changes — `data-attr-disabled="!!$item.validationErrors.name || !$item.hasUnsavedChanges"`
- **Minimise pattern**: `data-show` on `<section>` only, not the whole card — header and toggle always visible
- **Footer spacing**: `flex items-center justify-end gap-3` on all `<footer>` elements
- **Breadcrumb depth**: Dashboard > Items > ItemName > Edit (4 levels)
- **Delete on Edit**: uses `OnPostDeleteAsync` handler, redirects to Index
- **Update success**: `TempData["SuccessMessage"]` + `RedirectToPage("Details")`
