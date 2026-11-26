# CRUD pages

> Placeholders: `pkg` is the Java package, `Item` / `items` the feature. See SKILL.md.

The complete page set for one feature. The index page loads once. After that, search, paging, page size and delete all patch the table over SSE and never reload the page. Create and edit are ordinary forms that post and redirect.

The Java kit these pages lean on (`Sse`, `Signals`, `TableState`, `Message`) is in [datastar-sse.md](datastar-sse.md). The domain types (`Item`, `ItemId`, `ItemForm`, `ItemStore`) are in [domain-modeling.md](domain-modeling.md).

## How the index page works

1. `GET /items` renders the whole page. Table state comes from the query string, so `/items?search=bolt&page=3` opens on the right page.
2. The page declares one signal object, `items`, holding `search`, `page`, `pageSize` and the row waiting for delete confirmation.
3. Each control changes a signal and calls `@get('/items/table')`. Datastar sends the signals along.
4. The server reads the state from the signals, queries, and answers with the table fragment plus the state it actually used.
5. Delete posts to `/items/{id}/delete`. The answer is the table, the state and a toast.

The pager is made of buttons. A pager made of `<a href="/items?page=2">` links reloads the whole page on every click, which is the thing this design exists to avoid.

## Page records

Templates see page records and never the aggregate. Format values here so the template only prints strings.

```java
package pkg.features.items;

import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import pkg.web.Message;
import pkg.web.Signals;
import pkg.web.TableState;

public final class ItemPages {
    private static final DateTimeFormatter DAY = DateTimeFormatter.ofPattern("d MMM yyyy").withZone(ZoneOffset.UTC);

    private ItemPages() {}

    public record ItemRow(String id, String name, String price, boolean active, String created) {
        public static ItemRow of(Item item) {
            return new ItemRow(
                    item.id().toString(),
                    item.name(),
                    item.price().toPlainString(),
                    item.active(),
                    DAY.format(item.createdAt()));
        }
    }

    public record IndexPage(
            String userName,
            String csrfToken,
            List<Message> messages,
            List<ItemRow> rows,
            TableState table,
            int totalCount) {

        /** Initial signals. Built here so user text is JSON-encoded, never pasted into markup. */
        public String signals() {
            Map<String, Object> items = new LinkedHashMap<>(table.asSignals());
            items.put("pendingDeleteId", "");
            items.put("pendingDeleteName", "");
            return Signals.json(Map.of("items", items));
        }

        public int totalPages() {
            return table.totalPages(totalCount);
        }

        public int first() {
            return totalCount == 0 ? 0 : table.offset() + 1;
        }

        public int last() {
            return Math.min(table.offset() + table.pageSize(), totalCount);
        }

        public boolean hasPrevious() {
            return table.page() > 1;
        }

        public boolean hasNext() {
            return table.page() < totalPages();
        }
    }

    public record FormPage(
            String userName,
            String csrfToken,
            List<Message> messages,
            String heading,
            String action,
            String itemId,
            ItemForm form) {

        public boolean editing() {
            return !itemId.isEmpty();
        }
    }

    public record DetailsPage(String userName, String csrfToken, ItemRow item) {}
}
```

## `items/index.jte`

```html
@import pkg.features.items.ItemPages.IndexPage
@import pkg.web.TableState
@param IndexPage page

@template.layout.page(
    title = "Items",
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Items",
    content = @`
        <div data-signals="${page.signals()}">
            @template.fragments.messages(messages = page.messages())

            <div class="flex items-center justify-between gap-4 mb-6">
                <div class="flex items-center gap-4">
                    <a href="/items/new" class="btn-primary">Add item</a>
                    <label class="flex items-center gap-2 text-sm text-muted-foreground">
                        Show
                        <select class="input w-20" aria-label="Rows per page"
                                data-bind="items.pageSize"
                                data-on:change="$items.page = 1; @get('/items/table')"
                                data-indicator:_loading>
                            @for(int size : TableState.PAGE_SIZES)
                                <option value="${size}">${size}</option>
                            @endfor
                        </select>
                        rows
                    </label>
                </div>
                <input type="search" class="input w-64" placeholder="Search items" aria-label="Search items"
                       data-bind="items.search"
                       data-on:input__debounce.300ms="$items.page = 1; @get('/items/table')"
                       data-indicator:_loading>
            </div>

            @template.items.table(page = page)
        </div>

        <dialog id="delete-dialog" class="dialog w-full sm:max-w-md" aria-labelledby="delete-dialog-title"
                data-on:click="evt.target === el && el.close()">
            <article>
                <header>
                    <h2 id="delete-dialog-title">Delete item</h2>
                    <p>This cannot be undone.</p>
                </header>
                <section>
                    <p class="text-sm">Delete <strong data-text="$items.pendingDeleteName"></strong>?</p>
                </section>
                <footer>
                    <button type="button" class="btn-outline" data-on:click="el.closest('dialog').close()">Cancel</button>
                    <button type="button" class="btn-destructive"
                            data-on:click="el.closest('dialog').close(); @post('/items/' + $items.pendingDeleteId + '/delete')"
                            data-indicator:_loading>Delete</button>
                </footer>
            </article>
        </dialog>
    `
)
```

Points that matter:

- `data-signals="${page.signals()}"` prints JSON that Java built. JTE escapes it for the attribute. Never assemble a signals object by pasting `${...}` between quotes in the template.
- Search and page size reset `$items.page` to 1 before fetching. A filter that keeps you on page 7 of a result with two pages shows an empty table.
- The search input and the select sit outside `#items-table`. They are never replaced, so the cursor stays where it is while results arrive.
- `_loading` starts with an underscore, so it stays in the browser and is not sent to the server.
- One dialog serves every row. It sits outside the table so a table patch cannot remove it while it is open.

## `items/table.jte`

The fragment. The index page includes it, and the SSE handler renders it alone.

```html
@import pkg.features.items.ItemPages.IndexPage
@import pkg.features.items.ItemPages.ItemRow
@param IndexPage page

<div id="items-table" data-class="{ 'opacity-50 pointer-events-none': $_loading }">
    @if(page.rows().isEmpty())
        <div class="text-center py-12">
            <h3 class="text-lg font-medium mb-2">No items found</h3>
            @if(page.table().search().isEmpty())
                <p class="text-muted-foreground">Add the first one to get started.</p>
            @else
                <p class="text-muted-foreground">Nothing matches "${page.table().search()}".</p>
            @endif
        </div>
    @else
        <div class="overflow-x-auto">
            <table class="table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Price</th>
                        <th>Status</th>
                        <th>Created</th>
                        <th><span class="sr-only">Actions</span></th>
                    </tr>
                </thead>
                <tbody>
                    @for(ItemRow row : page.rows())
                        <tr>
                            <td class="font-medium"><a href="/items/${row.id()}" class="hover:underline">${row.name()}</a></td>
                            <td>${row.price()}</td>
                            <td><span class="${row.active() ? "badge-secondary" : "badge-outline"}">${row.active() ? "Active" : "Inactive"}</span></td>
                            <td>${row.created()}</td>
                            <td class="text-right">
                                <a href="/items/${row.id()}/edit" class="btn-sm-ghost">Edit</a>
                                <button type="button" class="btn-sm-ghost text-destructive"
                                        data-id="${row.id()}" data-name="${row.name()}"
                                        data-on:click="$items.pendingDeleteId = el.dataset.id; $items.pendingDeleteName = el.dataset.name; document.getElementById('delete-dialog').showModal()">
                                    Delete
                                </button>
                            </td>
                        </tr>
                    @endfor
                </tbody>
            </table>
        </div>

        <div class="flex items-center justify-between gap-4 py-4">
            <p class="text-sm text-muted-foreground">
                Showing ${page.first()} to ${page.last()} of ${page.totalCount()}
            </p>
            <nav class="flex items-center gap-2" aria-label="Pagination">
                <button type="button" class="btn-sm-outline" disabled="${!page.hasPrevious()}"
                        data-on:click="$items.page = ${page.table().page() - 1}; @get('/items/table')"
                        data-indicator:_loading>Previous</button>
                <span class="text-sm text-muted-foreground">Page ${page.table().page()} of ${page.totalPages()}</span>
                <button type="button" class="btn-sm-outline" disabled="${!page.hasNext()}"
                        data-on:click="$items.page = ${page.table().page() + 1}; @get('/items/table')"
                        data-indicator:_loading>Next</button>
            </nav>
        </div>
    @endif
</div>
```

Points that matter:

- The root `<div id="items-table">` is what the morph matches. Keep the id on the root of the fragment.
- The delete button carries the row's id and name in `data-id` and `data-name`, and the expression reads them with `el.dataset`. Do not write `$items.pendingDeleteName = '${row.name()}'`. A name with an apostrophe, such as O'Neil, ends the string early and breaks the handler, and a crafted name can run script.
- `disabled="${!page.hasPrevious()}"` is a JTE boolean attribute. It prints `disabled` or nothing.
- The pager writes the target page number from the server-rendered value, so a double click cannot skip a page.
- `data-class` dims the table while a request is in flight. That is all the feedback a table needs. Do not guess the next page in the browser.

## `fragments/messages.jte`

One container for every inline message on a page: flash after a redirect, validation errors, and messages patched over SSE. The id is always `messages`.

```html
@import pkg.web.Message
@import java.util.List
@param List<Message> messages

<div id="messages">
    @for(Message message : messages)
        <div class="${message.isError() ? "alert-destructive" : "alert"} mb-4" role="${message.isError() ? "alert" : "status"}" data-category="${message.category()}">
            <h2>${message.title()}</h2>
            @if(!message.lines().isEmpty())
                <section>
                    <ul>
                        @for(String line : message.lines())
                            <li>${line}</li>
                        @endfor
                    </ul>
                </section>
            @endif
            <button type="button" class="btn-sm-icon-ghost absolute right-2 top-2" aria-label="Dismiss"
                    data-on:click="el.parentElement.remove()">
                <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 6 6 18"/><path d="m6 6 12 12"/></svg>
            </button>
        </div>
    @endfor
</div>
```

With an empty list it renders an empty `<div id="messages">`, which is what gives later SSE patches a target.

## `fragments/toast.jte`

Appended to the `#toaster` element in the layout. Basecoat watches that element, shows each new toast and removes it after three seconds (five for `error`). Add `data-duration="8000"` to the toast to change that.

```html
@param String category
@param String title
@param String message

<div class="toast" role="${category.equals("error") ? "alert" : "status"}" aria-atomic="true" data-category="${category}">
    <div class="toast-content">
        @if(category.equals("success"))
            <svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m9 12 2 2 4-4"/></svg>
        @elseif(category.equals("error"))
            <svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="m15 9-6 6"/><path d="m9 9 6 6"/></svg>
        @else
            <svg aria-hidden="true" xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><path d="M12 16v-4"/><path d="M12 8h.01"/></svg>
        @endif
        <section>
            <h2>${title}</h2>
            <p>${message}</p>
        </section>
    </div>
</div>
```

## Which notification to use

| Situation | Success | Failure |
|-----------|---------|---------|
| Form post that redirects (create, edit) | Flash message on the next page | The form again, with errors in `#messages` |
| Datastar action that stays on the page (delete from the table) | Toast | Message patched into `#messages` |
| Unexpected exception during a Datastar action | n/a | Message patched into `#messages` by the exception handler |

A toast disappears, so use it only for news the user does not need to act on. Anything they must read stays in `#messages` until they dismiss it.

## Routes

```java
package pkg.features.items;

import io.javalin.http.Context;
import io.javalin.router.JavalinDefaultRoutingApi;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import pkg.ErrorDetail;
import pkg.Result;
import pkg.features.items.ItemPages.DetailsPage;
import pkg.features.items.ItemPages.FormPage;
import pkg.features.items.ItemPages.IndexPage;
import pkg.features.items.ItemPages.ItemRow;
import pkg.web.Message;
import pkg.web.SessionAuth;
import pkg.web.Signals;
import pkg.web.Sse;
import pkg.web.TableState;
import pkg.web.Templates;

public final class ItemRoutes {
    private static final String FLASH = "flash";

    private final ItemStore store;
    private final Clock clock;
    private final Templates templates;

    public ItemRoutes(ItemStore store, Clock clock, Templates templates) {
        this.store = store;
        this.clock = clock;
        this.templates = templates;
    }

    public void register(JavalinDefaultRoutingApi routes) {
        routes.get("/items", this::index);
        routes.get("/items/table", this::table);
        routes.get("/items/new", this::createForm);
        routes.post("/items", this::create);
        routes.get("/items/{id}", this::details);
        routes.get("/items/{id}/edit", this::editForm);
        routes.post("/items/{id}", this::update);
        routes.post("/items/{id}/delete", this::delete);
    }

    // ---- index: one full page, then every table interaction is a patch

    private void index(Context ctx) {
        IndexPage page = indexPage(ctx, TableState.fromQuery(ctx), flash(ctx));
        ctx.render("items/index.jte", Map.of("page", page));
    }

    private void table(Context ctx) {
        TableState asked = TableState.fromSignals(Signals.read(ctx), "/items");
        patchTable(Sse.open(ctx, templates), ctx, asked);
    }

    private void delete(Context ctx) {
        Optional<Item> found = ItemId.parse(ctx.pathParam("id")).flatMap(store::find);
        found.ifPresent(item -> store.delete(item.id()));

        if (!Sse.isDatastar(ctx)) {
            // posted from the edit page's danger zone: ordinary form, ordinary redirect
            ctx.sessionAttribute(FLASH, found.map(i -> "Deleted '" + i.name() + "'.").orElse("That item was already gone."));
            ctx.redirect("/items");
            return;
        }

        Sse sse = Sse.open(ctx, templates);
        patchTable(sse, ctx, TableState.fromSignals(Signals.read(ctx), "/items"));
        if (found.isPresent()) {
            sse.toast("success", "Item deleted", "'" + found.get().name() + "' has been deleted.");
        } else {
            sse.messages(List.of(new Message("warning", "That item was already gone.", List.of())));
        }
    }

    /** The one place a table fragment is produced, so search, paging, page size and delete cannot drift apart. */
    private void patchTable(Sse sse, Context ctx, TableState asked) {
        IndexPage page = indexPage(ctx, asked, List.of());
        sse.patch("items/table.jte", Map.of("page", page));
        sse.signals(Map.of("items", page.table().asSignals()));
    }

    private IndexPage indexPage(Context ctx, TableState asked, List<Message> messages) {
        int total = store.count(asked.search());
        TableState table = asked.clampTo(total);
        List<ItemRow> rows = store.findPage(table.search(), table.offset(), table.pageSize()).stream()
                .map(ItemRow::of)
                .toList();
        return new IndexPage(SessionAuth.userName(ctx), SessionAuth.csrfToken(ctx), messages, rows, table, total);
    }

    // ---- create and edit: ordinary forms, post then redirect

    private void createForm(Context ctx) {
        ctx.render("items/create.jte", Map.of("page", formPage(ctx, "", ItemForm.blank(), List.of())));
    }

    private void create(Context ctx) {
        ItemForm form = ItemForm.from(ctx);
        Result<Item> result = form.parse()
                .flatMap(v -> Item.create(v.name(), v.price(), v.active(), clock))
                .flatMap(this::nameIsFree);
        switch (result) {
            case Result.Ok<Item>(Item item) -> {
                store.insert(item);
                ctx.sessionAttribute(FLASH, "Created '" + item.name() + "'.");
                ctx.redirect("/items");
            }
            case Result.Err<Item>(List<ErrorDetail> errors) ->
                    ctx.render("items/create.jte", Map.of("page", formPage(ctx, "", form, errors)));
        }
    }

    private void details(Context ctx) {
        Optional<Item> found = ItemId.parse(ctx.pathParam("id")).flatMap(store::find);
        if (found.isEmpty()) {
            notFound(ctx);
            return;
        }
        ctx.render("items/details.jte", Map.of("page",
                new DetailsPage(SessionAuth.userName(ctx), SessionAuth.csrfToken(ctx), ItemRow.of(found.get()))));
    }

    private void editForm(Context ctx) {
        Optional<Item> found = ItemId.parse(ctx.pathParam("id")).flatMap(store::find);
        if (found.isEmpty()) {
            notFound(ctx);
            return;
        }
        Item item = found.get();
        ctx.render("items/edit.jte", Map.of("page", formPage(ctx, item.id().toString(), ItemForm.of(item), List.of())));
    }

    private void update(Context ctx) {
        Optional<Item> found = ItemId.parse(ctx.pathParam("id")).flatMap(store::find);
        if (found.isEmpty()) {
            notFound(ctx);
            return;
        }
        Item current = found.get();
        ItemForm form = ItemForm.from(ctx);
        Result<Item> result = form.parse()
                .flatMap(v -> current.change(v.name(), v.price(), v.active(), clock))
                .flatMap(this::nameIsFree);
        switch (result) {
            case Result.Ok<Item>(Item item) -> {
                store.update(item);
                ctx.sessionAttribute(FLASH, "Saved '" + item.name() + "'.");
                ctx.redirect("/items");
            }
            case Result.Err<Item>(List<ErrorDetail> errors) ->
                    ctx.render("items/edit.jte", Map.of("page", formPage(ctx, current.id().toString(), form, errors)));
        }
    }

    /** A rule that needs the database. It cannot live on the aggregate, so it lives next to the store call. */
    private Result<Item> nameIsFree(Item item) {
        return store.nameTaken(item.name(), item.id())
                ? Result.err("Item.Name.Taken", "Another item is already called '" + item.name() + "'.")
                : Result.ok(item);
    }

    private FormPage formPage(Context ctx, String itemId, ItemForm form, List<ErrorDetail> errors) {
        boolean editing = !itemId.isEmpty();
        List<Message> messages = errors.isEmpty()
                ? List.of()
                : List.of(Message.error(editing ? "Could not save the item" : "Could not create the item", errors));
        return new FormPage(
                SessionAuth.userName(ctx),
                SessionAuth.csrfToken(ctx),
                messages,
                editing ? "Edit item" : "New item",
                editing ? "/items/" + itemId : "/items",
                itemId,
                form);
    }

    private void notFound(Context ctx) {
        ctx.sessionAttribute(FLASH, "That item no longer exists.");
        ctx.redirect("/items");
    }

    private static List<Message> flash(Context ctx) {
        String text = ctx.sessionAttribute(FLASH);
        ctx.sessionAttribute(FLASH, null);
        return text == null ? List.of() : List.of(Message.success(text));
    }
}
```

Points that matter:

- Register `/items/new` and `/items/table` before `/items/{id}`. Otherwise `new` and `table` arrive as ids.
- `patchTable` always sends the signals after the fragment. Delete the last row on the last page and the server moves you to the new last page. The signal has to follow or the next click starts from a page that is gone.
- Delete answers two kinds of caller with one route. A Datastar request gets patches. A plain form post from the edit page gets a flash and a redirect.
- Deleting a row that is already gone is not an error worth a red box. Refresh the table and say so.
- The flash is read and cleared in the same request, so it shows once.

## `items/fields.jte`

The inputs that create and edit share.

```html
@import pkg.features.items.ItemForm
@param ItemForm form
@param String csrfToken

<input type="hidden" name="csrf" value="${csrfToken}">
<div class="grid gap-2">
    <label for="name">Name</label>
    <input id="name" name="name" class="input" type="text" value="${form.name()}" maxlength="100" required autofocus>
</div>
<div class="grid gap-2">
    <label for="price">Price</label>
    <input id="price" name="price" class="input" type="text" inputmode="decimal" value="${form.price()}" required>
</div>
<label class="flex items-center gap-2">
    <input name="active" class="input" type="checkbox" checked="${form.active()}">
    Active
</label>
```

The values come from `ItemForm`, which holds strings exactly as typed. After a failed save the user sees `abc` in the price box next to the message that says it is not a number.

## `items/create.jte`

```html
@import pkg.features.items.ItemPages.FormPage
@param FormPage page

@template.layout.page(
    title = page.heading(),
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Items",
    content = @`
        @template.fragments.messages(messages = page.messages())

        <form method="post" action="${page.action()}" class="form card max-w-xl">
            <header><h2>${page.heading()}</h2></header>
            <section class="grid gap-4">
                @template.items.fields(form = page.form(), csrfToken = page.csrfToken())
            </section>
            <footer class="flex gap-2">
                <button type="submit" class="btn-primary">Create</button>
                <a href="/items" class="btn-outline">Cancel</a>
            </footer>
        </form>
    `
)
```

A plain form. The browser posts it, the server redirects, the back button works. Do not put `data-on:submit` on it: Datastar prevents the default on a submit handler, and the form would stop posting.

## `items/edit.jte`

```html
@import pkg.features.items.ItemPages.FormPage
@param FormPage page

@template.layout.page(
    title = page.heading(),
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Items",
    content = @`
        @template.fragments.messages(messages = page.messages())

        <div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
            <form method="post" action="${page.action()}" class="form card lg:col-span-8"
                  data-signals:_dirty="${!page.messages().isEmpty()}" data-on:input="$_dirty = true">
                <header><h2>${page.heading()}</h2></header>
                <section class="grid gap-4">
                    @template.items.fields(form = page.form(), csrfToken = page.csrfToken())
                </section>
                <footer class="flex gap-2">
                    <button type="submit" class="btn-primary" data-attr:disabled="!$_dirty">Save</button>
                    <a href="/items" class="btn-outline">Cancel</a>
                </footer>
            </form>

            <div class="card lg:col-span-4 border-destructive/40">
                <header>
                    <h2 class="text-destructive">Danger zone</h2>
                    <p>Deleting an item cannot be undone.</p>
                </header>
                <footer>
                    <form method="post" action="/items/${page.itemId()}/delete"
                          onsubmit="return confirm('Delete this item?')">
                        <input type="hidden" name="csrf" value="${page.csrfToken()}">
                        <button type="submit" class="btn-destructive">Delete item</button>
                    </form>
                </footer>
            </div>
        </div>
    `
)
```

Save stays disabled until something changes. `_dirty` starts `true` when the page is showing errors, because then the form already holds unsaved input.

## `items/details.jte`

```html
@import pkg.features.items.ItemPages.DetailsPage
@param DetailsPage page

@template.layout.page(
    title = page.item().name(),
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Items",
    content = @`
        <div class="card max-w-xl">
            <header><h2>${page.item().name()}</h2></header>
            <section>
                <dl class="grid grid-cols-[8rem_1fr] gap-y-2 text-sm">
                    <dt class="text-muted-foreground">Price</dt><dd>${page.item().price()}</dd>
                    <dt class="text-muted-foreground">Status</dt><dd>${page.item().active() ? "Active" : "Inactive"}</dd>
                    <dt class="text-muted-foreground">Created</dt><dd>${page.item().created()}</dd>
                </dl>
            </section>
            <footer class="flex gap-2">
                <a href="/items/${page.item().id()}/edit" class="btn-primary">Edit</a>
                <a href="/items" class="btn-outline">Back to items</a>
            </footer>
        </div>
    `
)
```

## Check it in the browser

Before calling the feature done, with at least 25 rows in the table:

1. Click Next. The rows change, the address bar does not, and the network tab shows one `text/event-stream` request to `/items/table`.
2. Type in the search box. The table narrows after a short pause and the cursor stays in the box.
3. Change the page size. The table returns to page 1.
4. Delete a row whose name contains an apostrophe. The dialog shows the name intact, the row goes, a toast appears and then leaves by itself.
5. Go to the last page and delete every row on it. The table lands on the new last page.
6. Open `/items?page=2` directly. Page 2 loads.
7. Save an edit with a bad value. The form comes back with the message and with what was typed.
