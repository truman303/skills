# UI Component Patterns Reference

## Button Styling

### Primary Actions (Add New, Create, Submit)
```html
<a href="/Items/Create" class="btn btn-primary btn-ghost">
    <svg>...</svg>
    Add New Item
</a>
<button type="submit" class="btn btn-primary btn-ghost">Create Item</button>
```

### Secondary Actions (Back, Cancel, View, Export, Toggle)
```html
<a href="/Items" class="btn btn-outline btn-sm text-black dark:text-gray-300">
    <svg>...</svg>
    Back to Items
</a>
<button type="button" class="btn btn-outline btn-sm text-black dark:text-gray-300">Export</button>
```

### Icon-Only (Table Row Actions)
```html
<form asp-page="Details" asp-route-id="@item.Id" method="get" class="inline">
    <button type="submit"
            class="inline-flex items-center justify-center hover:scale-120 hover:text-secondary transition-transform"
            aria-label="View item">
        <svg width="22" height="22">...</svg>
    </button>
</form>
```
- Destructive icon actions: `hover:text-red-400` or `hover:text-red-600`
- Action container: `flex items-center gap-4` (not `gap-2`)

### Destructive Actions
```html
<button type="button" class="btn-destructive" data-on-click__passive="$item.showDeleteModal = true">
    Delete
</button>
```

## DataStar Signals

### Index/List Page Signals (plural namespace)
```html
<div data-signals="{
    items: {
        searchQuery: '@Model.SearchQuery',
        currentPage: @Model.CurrentPage,
        pageSize: @Model.PageSize,
        totalCount: @Model.TotalCount,
        loading: false,
        pendingDeleteId: '',
        pendingDeleteName: ''
    }
}" style="display: none;"></div>
```

### Create Page Signals (singular namespace)
```html
<div data-signals="{
    item: {
        name: '',
        active: true,
        validationErrors: {},
        loading: false,
        showGuidelines: true
    }
}" style="display: none;"></div>
```

### Edit Page Signals (singular with change tracking)
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

## DataStar Directives Quick Reference

| Directive | Purpose | Example |
|-----------|---------|---------|
| `data-signals` | Initialize reactive state | `data-signals="{ item: { name: '' } }"` |
| `data-bind` | Two-way binding | `data-bind="item.name"` |
| `data-show` | Conditional visibility | `data-show="$item.loading"` |
| `data-text` | Dynamic text | `data-text="$item.name"` |
| `data-class` | Conditional CSS | `data-class="{ 'active': $item.isActive }"` |
| `data-on-click` | Click handler (prevents default) | `data-on-click="..."` |
| `data-on-click__passive` | Click without preventing default | `data-on-click__passive="..."` |
| `data-on-click__once__passive` | Single click (prevent double) | Loading state on submit |
| `data-on-input__debounce.500ms` | Debounced input | Search fields |
| `data-on-submit` | Form submit with DataStar action | `data-on-submit="@@post(...)"` |
| `data-attr-disabled` | Dynamic disabled state | `data-attr-disabled="!!$item.validationErrors.name"` |
| `data-attr-href` | Dynamic href | `data-attr-href="'/Items/' + $item.id"` |
| `data-indicator-{ns}.loading` | Auto loading indicators | `data-indicator-items.loading` |

### DataStar Actions
- `@@get('/path?handler=Fragment&param=value')` — SSE fragment fetch
- `@@post('/path?handler=Action', { contentType: 'form', headers: { 'RequestVerificationToken': $antiForgeryToken } })` — SSE form post

## Button Disable Logic

- **Create pages**: `data-attr-disabled="!!$item.validationErrors.name"`
- **Edit pages**: `data-attr-disabled="!!$item.validationErrors.name || !$item.hasUnsavedChanges"`
- **Never** include `$item.loading` in disable logic (blocks form submission)

## Dropdown Menu (Basecoat)

**Required ARIA attributes** — without these, dropdowns won't close properly:

```html
<div id="my-dropdown" class="dropdown-menu">
    <button type="button"
            id="my-dropdown-trigger"
            aria-haspopup="menu"
            aria-controls="my-dropdown-menu"
            aria-expanded="false"
            class="btn btn-outline btn-sm text-black dark:text-gray-300">
        <span data-text="...">Display</span>
        <svg class="ml-1"><!-- chevron --></svg>
    </button>
    <div id="my-dropdown-popover" data-popover aria-hidden="true" class="min-w-24">
        <div role="menu" id="my-dropdown-menu" aria-labelledby="my-dropdown-trigger">
            <div role="menuitem" class="@(isSelected ? "bg-accent" : "")" data-on-click="...">
                Option
            </div>
        </div>
    </div>
</div>
```

## Status Badges

### Active/Inactive
```html
<span class="badge-outline"
      data-class="{
          'bg-accent text-black dark:text-black': @item.Active.ToString().ToLower(),
          'bg-muted text-black dark:text-white': !@item.Active.ToString().ToLower()
      }">
    @(item.Active ? "Active" : "Inactive")
</span>
```

### Multi-State with Color Dots
```html
<div class="flex items-center gap-2">
    <span class="inline-block size-2 rounded-full"
          data-class="{
              'bg-gray-400': ['NotStarted'].includes(status),
              'bg-orange-400': ['InProgress'].includes(status),
              'bg-green-400': ['Completed'].includes(status),
              'bg-red-400': ['Failed'].includes(status)
          }"></span>
    <span class="text-sm" data-text="statusMessage">@statusMessage</span>
</div>
```

Color guide: Gray=idle, Orange=in-progress, Green=success, Red=error.

## Page Layouts

### Two-Column Grid (Create, Edit, Details)
```html
<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
    <div class="lg:col-span-8"><!-- Main content --></div>
    <div class="lg:col-span-4 space-y-6"><!-- Sidebar --></div>
</div>
```

### Card Component (Semantic HTML)
```html
<div class="card">
    <header><h2>Title</h2><p>Description</p></header>
    <section class="grid gap-6"><!-- Fields --></section>
    <footer><!-- Actions --></footer>
</div>
```

## Breadcrumb Navigation

```html
<nav aria-label="breadcrumb" class="mb-4">
    <ol class="text-muted-foreground flex flex-wrap items-center gap-1.5 text-sm break-words sm:gap-2.5">
        <li class="inline-flex items-center gap-1.5">
            <a href="/" class="hover:text-foreground transition-colors">Dashboard</a>
        </li>
        <li>
            <svg class="size-3.5" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="m9 18 6-6-6-6"/></svg>
        </li>
        <li class="inline-flex items-center gap-1.5">
            <a href="/Items" class="hover:text-foreground transition-colors">Items</a>
        </li>
        <li><!-- chevron svg --></li>
        <li class="inline-flex items-center gap-1.5">
            <span class="text-foreground font-normal" aria-current="page">Current</span>
        </li>
    </ol>
</nav>
```

Depth: Index=2, Create=3, Details=3, Edit=4.

## Message Stack (Required on ALL Pages)

Always include in this exact order at the top of content:

```html
<!-- 1. TempData success (from redirects) -->
@if (TempData["SuccessMessage"] is not null)
{
    @await Html.PartialAsync("_Message", new MessageViewModel(
        Category: "success", Title: "Success",
        Message: TempData["SuccessMessage"]!.ToString()!,
        InfoMessage: TempData["InfoMessage"]?.ToString()
    ))
}

<!-- 2. Full page errors (non-dismissible) -->
@if (Model.ErrorDetails is not null && Model.ErrorDetails.Any())
{
    @await Html.PartialAsync("_Message", new MessageViewModel(
        Category: "error", Title: "Error",
        Message: $"{Model.ErrorDetails.Count} error{(Model.ErrorDetails.Count > 1 ? "s" : "")} occurred:",
        Errors: Model.ErrorDetails
    ))
}

<!-- 3. SSE message container (patched by DataStar) -->
<div id="sse-message-container"></div>
```

## Notification Decision Tree

| Context | Success | Error |
|---------|---------|-------|
| Redirect after Create/Edit | `TempData["SuccessMessage"]` | `ErrorDetails` on same page |
| SSE table fragment | `CreateAndPatchSuccessToastAsync` | `CreateAndPatchErrorMessageAsync` |
| SSE POST from table | Toast | Inline message |
| Full page GET | N/A | `ErrorDetails` |

## Client-Side Validation Pattern

```html
<div class="grid gap-2">
    <label for="name" class="text-sm font-medium">Name <span class="text-destructive">*</span></label>
    <input type="text" id="name" name="Name" class="input" placeholder="Enter name"
           data-bind="item.name"
           data-on-input="$item.validationErrors.name = $item.name.trim().length < 2 ? 'Min 2 chars' : ($item.name.length > 100 ? 'Max 100 chars' : '')"
           data-class="{ 'border-destructive': !!$item.validationErrors.name }" />
    <p class="text-sm text-destructive" data-show="!!$item.validationErrors.name" data-text="$item.validationErrors.name"></p>
    <span asp-validation-for="Name" class="text-sm text-destructive"></span>
</div>
```

## Delete Confirmation Dialog

```html
<dialog id="delete-dialog" class="dialog w-full sm:max-w-md" data-on-click="if (evt.target === el) el.close()">
    <article>
        <header>
            <h2 class="text-red-600">Delete item</h2>
            <p>Confirm permanent removal.</p>
        </header>
        <section>
            <div class="p-3 bg-red-50 dark:bg-red-950/30 border border-red-200 dark:border-red-900 rounded-lg">
                <p class="text-sm text-red-800 dark:text-red-200"><strong>Warning:</strong> This cannot be undone.</p>
            </div>
            <p class="text-sm text-muted-foreground mt-3">Delete <strong data-text="$items.pendingDeleteName"></strong>?</p>
        </section>
        <footer>
            <button type="button" class="btn btn-outline btn-sm text-black dark:text-gray-300" data-on-click="el.closest('dialog').close()">Cancel</button>
            <form method="post" class="inline"
                  data-on-submit="el.closest('dialog').close(); @@post('/Items?handler=Delete', {
                      contentType: 'form', headers: { 'RequestVerificationToken': $antiForgeryToken }
                  })">
                <input type="hidden" name="id" data-bind="items.pendingDeleteId" />
                <button type="submit" class="btn-destructive">Delete</button>
            </form>
        </footer>
    </article>
</dialog>
```

## Danger Zone (Edit Pages)

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
