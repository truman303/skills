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

## Edit Signals (Change Tracking)

Store `original*` baseline values alongside live values for accurate change detection:

```html
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
```

## Submit Button (Edit-Specific Disable)

Disable for validation errors **OR** no changes (unlike Create which only checks validation):

```html
<button type="submit" class="btn btn-primary btn-ghost"
        data-attr-disabled="!!$item.validationErrors.name || !$item.hasUnsavedChanges">
    Save Changes
</button>
```

## Unsaved Changes Warning

```html
<div data-show="$item.hasUnsavedChanges" class="mt-2 p-2 bg-amber-50 border border-amber-200 rounded-lg">
    <p class="text-sm text-amber-800 flex items-center">You have unsaved changes</p>
</div>
```

## Danger Zone

Collapsible section at the bottom of the main content column:

```html
<div class="lg:col-span-8">
    <div class="card border-red-200 dark:border-red-900" data-show="$item.showDangerZone">
        <header>
            <div class="flex items-center justify-between">
                <h3 class="text-red-600">Danger Zone</h3>
                <button type="button" class="btn btn-outline btn-sm text-black dark:text-gray-300"
                        data-on-click__passive="$item.showDangerZone = !$item.showDangerZone">
                    <svg data-class="{ 'rotate-180': $item.showDangerZone }"><!-- chevron --></svg>
                </button>
            </div>
        </header>
        <section>
            <p class="text-sm text-muted-foreground mb-4">Permanently delete this item. This cannot be undone.</p>
            <button type="button" class="btn-destructive"
                    data-on-click__passive="$item.showDeleteModal = true">
                Delete Item
            </button>
        </section>
    </div>
</div>
```

## Delete Confirmation Modal (Edit Page)

Requires typing the item name to confirm:

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
        <footer>
            <button type="button" class="btn btn-outline btn-sm text-black dark:text-gray-300"
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

- **Signals**: singular namespace (`item`) with `original*` baselines and `hasUnsavedChanges`
- **Submit disable**: validation errors + no changes — `data-attr-disabled="!!$item.validationErrors.name || !$item.hasUnsavedChanges"`
- **Breadcrumb depth**: Dashboard > Items > ItemName > Edit (4 levels)
- **Delete on Edit**: uses `OnPostDeleteAsync` handler, redirects to Index
- **Update success**: `TempData["SuccessMessage"]` + `RedirectToPage("Details")`
