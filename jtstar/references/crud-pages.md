# CRUD pages (JTE)

All Datastar actions in `.jte` files use `@@get` / `@@post` so JTE does not eat the `@`. See [jte-templates.md](jte-templates.md).

## Index + table fragment

`items/index.jte` is the full page. It includes the table template. Search and pagination call `/items/table`.

```
@import pkg.features.items.ItemIndexPage
@param ItemIndexPage page

@template.layout.page(
    title = "Items",
    userName = page.userName(),
    authenticated = true,
    currentPage = "Items",
    content = @`
        <div data-signals="{ items: { searchQuery: '${page.searchQuery()}', loading: false } }">
            <div id="page-messages"></div>
            <div id="sse-message-container"></div>

            <div class="flex items-center justify-between mb-4">
                <h1 class="text-2xl font-semibold">Items</h1>
                <a href="/items/new" class="btn btn-primary btn-ghost">Add item</a>
            </div>

            <input class="input" placeholder="Search"
                   data-bind="items.searchQuery"
                   data-on:input__debounce.300ms="@@get('/items/table')">

            @template.items.table(page = page)
        </div>
    `
)
```

`items/table.jte` wraps rows in `<div id="items-table">`. Empty state uses `@for ... @else`.

Delete on a row:

```
<button class="btn-destructive"
        data-on:click="@@post('/items/${item.id()}/delete')">
    Delete
</button>
```

`table` GET handler: load rows from query/signal, `Sse.patch(ctx, html)`.

`delete` POST: `store.delete`, re-render table, patch it, append a toast to `#toaster`.

Pagination: links that `@get('/items/table?page=2')` or patch signals then GET. Keep `pageSize` on the server default (10).

## Create

Two-column grid. Main: form fields. Sidebar: guidelines card (collapsible, `data-show` on the `<section>` only).

```
<form method="post" action="/items">
    <input type="hidden" name="csrf" data-bind="csrfToken">
    <label>Name</label>
    <input class="input" name="name" data-bind="item.name"
           data-on:input="$item.validationErrors.name = $item.name.trim().length < 2 ? 'Min 2 chars' : ''">
    <p class="text-sm text-destructive" data-show="!!$item.validationErrors.name"
       data-text="$item.validationErrors.name"></p>
    <button class="btn btn-primary" data-indicator:_loading>Create</button>
</form>
```

Server still validates. Client hints are not a substitute for `Item.create(...)`.

Success: session flash, `ctx.redirect("/items")`.

## Edit

Same form bound to current values. `hasUnsavedChanges` signal comparing to originals.

Danger zone: collapsible card, `data-show` on `<section>` only. Delete opens a `<dialog>`, POST `/items/{id}/delete`, redirect index.

Disable submit when `!!$item.validationErrors.name || !$item.hasUnsavedChanges`. Do not include `$item.loading` in the disabled expression (blocks the submit).

## Details

Read-only definition list. Sidebar: quick actions (Edit, Back). No SSE.

## Message stack (every full page)

1. Flash success from session (then clear)
2. `page.errors()` if the GET itself failed
3. `<div id="sse-message-container"></div>` for Datastar patches

## hydra campaign page (not CRUD, same bones)

Form: campaign id, profile version, POST to `/campaigns`.

```html
<div id="campaign-progress" data-init="@@get('/campaigns/${id}/live')">
    ...counts from CampaignProgress...
</div>
```

Live handler: loop `orchestration.campaignProgress(id)`, render `campaigns/progress.jte`, patch `#campaign-progress` when the record changes. See [attach-modular-monolith.md](attach-modular-monolith.md).
