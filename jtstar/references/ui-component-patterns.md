# UI component patterns

Basecoat supplies the component classes, Tailwind the utilities, Datastar the behaviour. Complete pages that use everything here are in [crud-pages.md](crud-pages.md).

## Basecoat classes

Basecoat names each variant as one class. Sizes and styles combine in the name, not as separate classes.

| Element | Classes |
|---------|---------|
| Button | `btn-primary`, `btn-secondary`, `btn-outline`, `btn-ghost`, `btn-destructive`, `btn-link` |
| Small or large button | `btn-sm-outline`, `btn-sm-ghost`, `btn-lg-primary` |
| Icon-only button | `btn-icon-outline`, `btn-sm-icon-ghost`. Always add `aria-label`. |
| Text input, select, checkbox | `input` |
| Text area | `textarea` |
| Form wrapper | `form` on the `<form>` |
| Card | `card` with `<header>`, `<section>`, `<footer>` children |
| Table | `table` |
| Badge | `badge-primary`, `badge-secondary`, `badge-outline`, `badge-destructive` |
| Inline message | `alert`, `alert-destructive` |
| Dialog | `dialog` on a `<dialog>`, with an `<article>` holding `<header>`, `<section>`, `<footer>` |
| Toast | `toast` inside the `toaster` |
| Menu | `dropdown-menu`, `popover` |

`btn btn-primary btn-sm` is not how this version works. Write `btn-sm-primary`.

A link that should look like a button takes the same class: `<a href="/items/new" class="btn-primary">Add item</a>`.

## Links and buttons

- Going to another page is an `<a href>`. The browser handles history, middle-click and the back button.
- Doing something on the current page is a `<button type="button">` with `data-on:click`.
- Submitting a form is a `<button type="submit">` inside a `<form method="post">`.

Always write `type="button"` on a button that is not a submit. A bare `<button>` inside a form submits it.

## Datastar attributes

| Attribute | Purpose |
|-----------|---------|
| `data-signals="${page.signals()}"` | Declare signals with their first values, as JSON built in Java |
| `data-signals:_dirty="false"` | Declare one signal inline |
| `data-bind="items.search"` | Two-way bind an input, select or checkbox to a signal |
| `data-text="$items.pendingDeleteName"` | Set an element's text from an expression |
| `data-show="$_open"` | Show or hide |
| `data-class="{ 'opacity-50': $_loading }"` | Toggle classes |
| `data-attr:disabled="!$_dirty"` | Set or remove an attribute |
| `data-on:click="..."` | Run an expression on an event |
| `data-on:input__debounce.300ms="..."` | The same, 300 ms after the last keystroke |
| `data-indicator:_loading` | Set a signal to `true` while this element's request is in flight |
| `data-init="@get('/jobs/live')"` | Run once when the element appears. Opens live views. |

Inside an expression, `el` is the element, `evt` is the event, `$name` is a signal and `@get(...)` or `@post(...)` calls the server.

Event modifiers are added with a double underscore: `__debounce.300ms`, `__throttle.1s`, `__prevent` to cancel the browser's default action, `__stop` to stop propagation, `__window` to listen on the window, `__outside` for clicks outside the element.

A plain `data-on:click` does not cancel the default action. `data-on:submit` does, on its own. So never put `data-on:submit` on a form the browser is meant to post.

## Signals

Keep them few. A signal is for what the user is typing or toggling, plus what the server needs sent back.

- An index page declares one object named after the feature in the plural: `items: { search, page, pageSize, pendingDeleteId, pendingDeleteName }`. The server reads it with `TableState.fromSignals(signals, "/items")`.
- Signals that only the browser cares about start with an underscore: `_loading`, `_dirty`, `_open`. Datastar does not send those to the server.
- Build the initial object in Java and print it with `data-signals="${page.signals()}"`. Do not write the object literal in the template with `${...}` between quotes. One apostrophe in a value breaks every expression on the page.
- Do not mirror server data into signals. The table's rows are HTML, not a signal array.

## Loading feedback

Put `data-indicator:_loading` on each control that fetches, and dim the region that will change:

```html
<div id="items-table" data-class="{ 'opacity-50 pointer-events-none': $_loading }">
```

`pointer-events-none` also stops a second click on the pager while the first is in flight.

## Messages and toasts

Every full page renders `@template.fragments.messages(messages = page.messages())` near the top. That one `<div id="messages">` shows:

- the flash message after a redirect
- validation errors when a form is shown again
- anything a later Datastar action patches in, including unexpected errors

A toast is for good news about an action that kept the user on the page. `sse.toast("success", "Item deleted", "...")` appends it to `#toaster` in the layout, and Basecoat removes it after a few seconds.

| Situation | Use |
|-----------|-----|
| Created or saved, then redirected | Flash in `#messages` on the next page |
| Deleted from a table row | Toast |
| Validation failed | `#messages` on the form page |
| Something the user must read or act on | `#messages`, never a toast |

## Confirm dialog

One `<dialog>` per page, outside any fragment that gets patched. The row button stores which row is meant and opens it. The confirm button closes it and posts.

```html
<button type="button" class="btn-sm-ghost text-destructive"
        data-id="${row.id()}" data-name="${row.name()}"
        data-on:click="$items.pendingDeleteId = el.dataset.id; $items.pendingDeleteName = el.dataset.name; document.getElementById('delete-dialog').showModal()">
    Delete
</button>
```

```html
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
```

- `showModal()` gives focus trapping and Escape for free.
- `evt.target === el && el.close()` closes on a backdrop click.
- The name travels through `data-name` and `el.dataset`, never through string interpolation into the expression.

## Dirty tracking on edit forms

```html
<form method="post" action="${page.action()}" class="form card"
      data-signals:_dirty="${!page.messages().isEmpty()}" data-on:input="$_dirty = true">
    ...
    <button type="submit" class="btn-primary" data-attr:disabled="!$_dirty">Save</button>
</form>
```

Save is disabled until a field changes. When the form is shown again after a failed save, `_dirty` starts `true`.

## Page layouts

Two columns, main content and a side panel:

```html
<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
    <div class="lg:col-span-8">...</div>
    <div class="lg:col-span-4 space-y-6">...</div>
</div>
```

Card:

```html
<div class="card">
    <header><h2>Title</h2><p>Optional description</p></header>
    <section>...</section>
    <footer>...</footer>
</div>
```

To make a card collapsible, put `data-show` on the `<section>`. If it goes on the card, the toggle button disappears with it.

## Status badges

Two states: `badge-secondary` for the normal one, `badge-outline` for the muted one. Choose the class on the server:

```html
<span class="${row.active() ? "badge-secondary" : "badge-outline"}">${row.active() ? "Active" : "Inactive"}</span>
```

For a workflow with several states, map each state to a badge class in the page record and print it. Keep one meaning per colour across the app: `badge-outline` waiting, `badge-secondary` in progress, `badge-primary` done, `badge-destructive` failed.

## Danger zone

Destructive actions on an edit page sit apart, in a card with `border-destructive/40`, and are a plain form with the CSRF field. See `items/edit.jte` in [crud-pages.md](crud-pages.md).

## Dropdown menu

Basecoat's dropdown needs its ARIA attributes to open and close: `aria-haspopup="menu"`, `aria-controls` and `aria-expanded` on the trigger, `data-popover` on the popover, `role="menu"` on the list and `role="menuitem"` on each entry. Copy the markup from the Basecoat documentation for the bundled version and do not trim it.

## Accessibility basics

- Every icon-only button has an `aria-label`.
- Every input has a `<label for>` or an `aria-label`.
- An error message uses `role="alert"`, a status message `role="status"`. The message and toast fragments already do this.
- The current nav link carries `aria-current="page"`. The sidebar styles depend on it.
