# Index Page (Table with SSE Fragments)

Table/list page with search, pagination, SSE fragment updates, and inline delete.

## Table of Contents

- [Index.cshtml.cs](#indexcshtmlcs-pagemodel)
- [Index.cshtml](#indexcshtml-main-page)
- [_ItemsTable.cshtml](#_itemstablecshtml-table-partial)

## Index.cshtml.cs (PageModel)

```csharp
using ErrorOr;
using MediatR;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.RazorPages;
using StarFederation.Datastar.DependencyInjection;

public class IndexModel : PageModel
{
    private readonly IMediator _mediator;
    private readonly ILogger<IndexModel> _logger;
    private readonly IDatastarService _datastarService;

    public IndexModel(IMediator mediator, ILogger<IndexModel> logger, IDatastarService datastarService)
    {
        _mediator = mediator;
        _logger = logger;
        _datastarService = datastarService;
    }

    public List<ItemDto> Items { get; set; } = [];

    [BindProperty(SupportsGet = true)]
    public string? SearchQuery { get; set; }

    [BindProperty(SupportsGet = true)]
    public int CurrentPage { get; set; } = 1;

    [BindProperty(SupportsGet = true)]
    public int PageSize { get; set; } = 10;

    public int TotalCount { get; set; }
    public int TotalPages => (int)Math.Ceiling(TotalCount / (double)PageSize);

    public List<ErrorDetail>? ErrorDetails { get; private set; } = [];

    // Full page load — non-dismissible errors
    public async Task OnGetAsync(CancellationToken cancellationToken)
    {
        var result = await LoadItemsAsync(cancellationToken);
        if (result.IsError)
            ErrorDetails = result.Errors.ToErrorDetails();
    }

    // SSE table fragment — dismissible inline messages
    public async Task<IActionResult> OnGetTableFragmentAsync(CancellationToken cancellationToken)
    {
        try
        {
            return await LoadItemsAsync(cancellationToken).MatchAsync(
                success => this.CreateAndPatchPartialAsync(this, "_ItemsTable", _datastarService, _logger, cancellationToken),
                errors => this.CreateAndPatchErrorMessageAsync(errors, _datastarService, _logger, cancellationToken));
        }
        catch (Exception ex) when (ex is OperationCanceledException or TaskCanceledException)
        {
            _logger.LogInformation(ex, "Fragment patch cancelled");
            return new EmptyResult();
        }
    }

    // POST delete — toast on success, inline message on error
    [ValidateAntiForgeryToken]
    public async Task<IActionResult> OnPostDeleteAsync(string id, string? deletedName, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _mediator.Send(new DeleteItemCommand(id), cancellationToken);
            if (result.IsError)
                return await this.CreateAndPatchErrorMessageAsync(result.Errors, _datastarService, _logger, cancellationToken);

            await LoadItemsAsync(cancellationToken);
            await this.CreateAndPatchPartialAsync(this, "_ItemsTable", _datastarService, _logger, cancellationToken);

            return await this.CreateAndPatchSuccessToastAsync(
                ItemsToasts.Deleted(deletedName), _datastarService, cancellationToken);
        }
        catch (Exception ex) when (ex is OperationCanceledException or TaskCanceledException)
        {
            return new EmptyResult();
        }
    }

    private async Task<ErrorOr<Success>> LoadItemsAsync(CancellationToken cancellationToken)
    {
        var result = await _mediator.Send(new GetItemsQuery(), cancellationToken);
        if (result.IsError)
        {
            Items = [];
            TotalCount = 0;
            return result.Errors;
        }

        var items = result.Value.ToList();

        if (!string.IsNullOrWhiteSpace(SearchQuery))
        {
            items = items.Where(i =>
                i.Name.Contains(SearchQuery, StringComparison.OrdinalIgnoreCase)).ToList();
        }

        TotalCount = items.Count;
        Items = items.Skip((CurrentPage - 1) * PageSize).Take(PageSize).ToList();
        return Result.Success;
    }
}

// Page-specific errors (separate from domain ItemErrors)
public static class ItemsErrors
{
    public static Error LoadingItems() => Error.Failure(
        "Items.LoadFailed", "Failed to load items. Please try again.");
    public static Error DeletingItem() => Error.Failure(
        "Items.DeleteFailed", "Failed to delete item. Please try again.");
}

public static class ItemsToasts
{
    public static ToastModel Deleted(string? name = null) => new(
        title: "Item deleted",
        message: string.IsNullOrWhiteSpace(name)
            ? "The item has been deleted."
            : $"Item '{name}' has been deleted.");
}
```

## Index.cshtml (Main Page)

```html
@page
@model MyApp.Pages.Items.IndexModel
@{
    ViewData["Title"] = "Items";
}

<!-- Signal initialization -->
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

<div class="space-y-6">
    <!-- 1. TempData success messages -->
    @if (TempData["SuccessMessage"] is not null)
    {
        @await Html.PartialAsync("_Message", new MessageViewModel(
            Category: "success", Title: "Success",
            Message: TempData["SuccessMessage"]!.ToString()!,
            InfoMessage: TempData["InfoMessage"]?.ToString()
        ))
    }

    <!-- 2. Full page load errors -->
    @if (Model.ErrorDetails is not null && Model.ErrorDetails.Any())
    {
        @await Html.PartialAsync("_Message", new MessageViewModel(
            Category: "error", Title: "Error",
            Message: $"{Model.ErrorDetails.Count} error{(Model.ErrorDetails.Count > 1 ? "s" : "")} occurred:",
            Errors: Model.ErrorDetails
        ))
    }

    <!-- 3. SSE message container -->
    <div id="sse-message-container"></div>

    <!-- Page header -->
    <div class="mb-6">
        <h1 class="text-2xl font-bold mb-2">Items</h1>
        <p class="text-muted-foreground">View and manage items.</p>
    </div>

    <!-- Action bar -->
    <div class="flex items-center justify-between gap-4 mb-6">
        <div class="flex items-center gap-4">
            <a href="/Items/Create" class="btn btn-primary btn-ghost">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                    <path d="M5 12h14"/><path d="M12 5v14"/>
                </svg>
                Add Item
            </a>

            <!-- Page size dropdown (ARIA attributes required for Basecoat) -->
            <div class="flex items-center gap-2 text-sm text-muted-foreground">
                <span>Show</span>
                <div id="page-size-dropdown" class="dropdown-menu">
                    <button type="button" id="page-size-dropdown-trigger"
                            aria-haspopup="menu" aria-controls="page-size-dropdown-menu" aria-expanded="false"
                            class="btn btn-outline btn-sm text-foreground">
                        <span data-text="$items.pageSize"></span>
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="ml-1"><path d="m6 9 6 6 6-6"/></svg>
                    </button>
                    <div id="page-size-dropdown-popover" data-popover aria-hidden="true" class="min-w-24">
                        <div role="menu" id="page-size-dropdown-menu" aria-labelledby="page-size-dropdown-trigger">
                            @foreach (var size in new[] { 10, 25, 50, 100 })
                            {
                                <div role="menuitem" class="@(Model.PageSize == size ? "bg-accent" : "")"
                                     data-on-click="$items.pageSize = @size; @@get('/Items?handler=TableFragment&pageSize=@size&currentPage=1&searchQuery=' + encodeURIComponent($items.searchQuery))"
                                     data-indicator-items.loading>
                                    @size
                                </div>
                            }
                        </div>
                    </div>
                </div>
                <span>entries</span>
            </div>
        </div>

        <!-- Search -->
        <div class="relative">
            <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="absolute left-3 top-1/2 transform -translate-y-1/2 text-muted-foreground">
                <circle cx="11" cy="11" r="8"/><path d="m21 21-4.35-4.35"/>
            </svg>
            <input type="text" placeholder="Search items..." class="btn-outline pl-10 pr-4 py-2 w-64"
                   data-bind="items.searchQuery"
                   data-on-input__debounce.500ms="@@get('/Items?handler=TableFragment&searchQuery=' + encodeURIComponent($items.searchQuery) + '&pageSize=' + $items.pageSize + '&currentPage=1')"
                   data-indicator-items.loading />
            <span data-show="$items.loading" class="absolute right-3 top-1/2 transform -translate-y-1/2">
                <div class="animate-spin inline-block size-4 border-2 border-primary border-t-transparent rounded-full"></div>
            </span>
        </div>
    </div>

    @await Html.PartialAsync("_ItemsTable", Model)
</div>

<!-- Delete confirmation dialog -->
<dialog id="delete-dialog" class="dialog w-full sm:max-w-md" data-on-click="if (evt.target === el) el.close()">
    <article>
        <header>
            <h2 class="text-red-600">Delete item</h2>
            <p>Confirm permanent removal.</p>
        </header>
        <section>
            <p class="text-sm text-muted-foreground">
                Delete <strong data-text="$items.pendingDeleteName"></strong>?
            </p>
        </section>
        <footer>
            <button type="button" class="btn btn-outline btn-sm text-foreground" data-on-click="el.closest('dialog').close()">Cancel</button>
            <form method="post" class="inline" data-indicator-items.loading
                  data-on-submit="el.closest('dialog').close(); @@post('/Items?handler=Delete', {
                      contentType: 'form',
                      headers: { 'RequestVerificationToken': $antiForgeryToken }
                  })">
                <input type="hidden" name="id" data-bind="items.pendingDeleteId" />
                <input type="hidden" name="deletedName" data-bind="items.pendingDeleteName" />
                <input type="hidden" name="SearchQuery" data-bind="items.searchQuery" />
                <input type="hidden" name="CurrentPage" data-bind="items.currentPage" />
                <input type="hidden" name="PageSize" data-bind="items.pageSize" />
                <button type="submit" class="btn-destructive">Delete</button>
            </form>
        </footer>
    </article>
</dialog>
```

## _ItemsTable.cshtml (Table Partial)

```html
@model MyApp.Pages.Items.IndexModel

<div id="items-table-container" data-class="{ 'opacity-50 pointer-events-none transition-opacity duration-200': $items.loading }">

    @if (!Model.Items.Any())
    {
        <div class="text-center py-12">
            <h3 class="text-lg font-medium mb-2">No items found</h3>
            <p class="text-muted-foreground">
                @if (!string.IsNullOrWhiteSpace(Model.SearchQuery))
                {
                    <span>No items match your search. </span>
                    <a href="/Items" class="text-primary hover:underline">Clear search</a>
                }
                else
                {
                    <span>Get started by creating your first item.</span>
                }
            </p>
        </div>
    }
    else
    {
        <div class="overflow-x-auto">
            <table class="table">
                <caption>A list of items.</caption>
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Status</th>
                        <th>Created</th>
                        <th>Actions</th>
                    </tr>
                </thead>
                <tbody>
                    @foreach (var item in Model.Items)
                    {
                        <tr>
                            <td class="font-medium">@item.Name</td>
                            <td>
                                <span class="badge-outline"
                                      data-class="{
                                          'bg-accent text-accent-foreground': @item.Active.ToString().ToLower(),
                                          'bg-muted text-muted-foreground': !@item.Active.ToString().ToLower()
                                      }">
                                    @(item.Active ? "Active" : "Inactive")
                                </span>
                            </td>
                            <td>@item.CreatedTs.ToString("MMM d, yyyy")</td>
                            <td>
                                <div class="flex items-center gap-4">
                                    <form asp-page="Details" asp-route-id="@item.Id" method="get" class="inline">
                                        <button type="submit" class="inline-flex items-center justify-center hover:scale-120 hover:text-secondary transition-transform" aria-label="View">
                                            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M2 12s3-7 10-7 10 7 10 7-3 7-10 7-10-7-10-7Z"/><circle cx="12" cy="12" r="3"/></svg>
                                        </button>
                                    </form>
                                    <form asp-page="Edit" asp-route-id="@item.Id" method="get" class="inline">
                                        <button type="submit" class="inline-flex items-center justify-center hover:scale-120 hover:text-secondary transition-transform" aria-label="Edit">
                                            <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17 3a2.85 2.83 0 1 1 4 4L7.5 20.5 2 22l1.5-5.5Z"/><path d="m15 5 4 4"/></svg>
                                        </button>
                                    </form>
                                    <button type="button"
                                            class="inline-flex items-center justify-center hover:scale-120 hover:text-red-600 transition-transform"
                                            aria-label="Delete"
                                            data-on-click__passive="$items.pendingDeleteId = '@item.Id'; $items.pendingDeleteName = '@item.Name'; document.getElementById('delete-dialog').showModal()">
                                        <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M3 6h18"/><path d="M19 6v14c0 1-1 2-2 2H7c-1 0-2-1-2-2V6"/><path d="M8 6V4c0-1 1-2 2-2h4c1 0 2 1 2 2v2"/></svg>
                                    </button>
                                </div>
                            </td>
                        </tr>
                    }
                </tbody>
            </table>
        </div>

        <!-- Pagination -->
        @if (Model.TotalCount > 0)
        {
            <div class="flex items-center justify-between gap-4 py-4">
                <p class="text-sm text-muted-foreground">
                    Showing <span class="font-medium">@((Model.CurrentPage - 1) * Model.PageSize + 1)</span>
                    to <span class="font-medium">@Math.Min(Model.CurrentPage * Model.PageSize, Model.TotalCount)</span>
                    of <span class="font-medium">@Model.TotalCount</span>
                </p>
                <nav role="navigation" aria-label="pagination">
                    <ul class="flex flex-row items-center gap-1">
                        @if (Model.CurrentPage > 1)
                        {
                            <li>
                                <button type="button" class="btn-ghost"
                                        data-on-click="@@get('/Items?handler=TableFragment&currentPage=@(Model.CurrentPage - 1)&pageSize=' + $items.pageSize + '&searchQuery=' + encodeURIComponent($items.searchQuery))"
                                        data-indicator-items.loading>Previous</button>
                            </li>
                        }
                        @for (var i = 1; i <= Model.TotalPages; i++)
                        {
                            <li>
                                @if (i == Model.CurrentPage)
                                {
                                    <button type="button" class="btn-icon-outline" disabled>@i</button>
                                }
                                else
                                {
                                    <button type="button" class="btn-icon-ghost"
                                            data-on-click="@@get('/Items?handler=TableFragment&currentPage=@i&pageSize=' + $items.pageSize + '&searchQuery=' + encodeURIComponent($items.searchQuery))"
                                            data-indicator-items.loading>@i</button>
                                }
                            </li>
                        }
                        @if (Model.CurrentPage < Model.TotalPages)
                        {
                            <li>
                                <button type="button" class="btn-ghost"
                                        data-on-click="@@get('/Items?handler=TableFragment&currentPage=@(Model.CurrentPage + 1)&pageSize=' + $items.pageSize + '&searchQuery=' + encodeURIComponent($items.searchQuery))"
                                        data-indicator-items.loading>Next</button>
                            </li>
                        }
                    </ul>
                </nav>
            </div>
        }
    }
</div>
```
