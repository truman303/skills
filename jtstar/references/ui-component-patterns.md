# UI component patterns

Basecoat + Datastar. Same CSS as RazorStar. In `.jte` files, Datastar actions are `@@get` / `@@post`.

## Buttons

Primary: `btn btn-primary btn-ghost`. Secondary: `btn btn-outline btn-sm text-foreground`. Destructive: `btn-destructive`. Icon-only row actions: `inline-flex ... hover:scale-120`, `aria-label` required.

Links are `<a href="/items/new">`. There is no `asp-page`.

## Signals

Index (plural namespace):

```html
<div data-signals="{ items: { searchQuery: '', loading: false, pendingDeleteId: '' } }"></div>
```

Create/edit (singular): `item.name`, `item.validationErrors`, `item.loading`, `hasUnsavedChanges` on edit.

Put JSON together in the page record if interpolation gets messy. A broken `data-signals` object is a silent Datastar death.

## Directives

| Directive | Purpose |
|-----------|---------|
| `data-signals` | Initial state |
| `data-bind` | Two-way |
| `data-show` | Visibility |
| `data-text` | Text |
| `data-class` | Class map |
| `data-on:click` | Click (prevent default) |
| `data-on:click__passive` | Click, keep default |
| `data-on:input__debounce.300ms` | Search |
| `data-indicator:_loading` | Loading flag |
| `data-attr:disabled` | Disabled |

Actions: `@@get('/items/table')`, `@@post('/items')`.

Disable create when `!!$item.validationErrors.name`. Edit: also `|| !$item.hasUnsavedChanges`. Never fold `loading` into disabled.

## Dropdown (Basecoat)

ARIA is required or the menu will not close:

`aria-haspopup="menu"`, `aria-controls`, `aria-expanded`, `role="menu"`, `role="menuitem"`, `data-popover` on the popover.

## Badges

Active: `badge-outline` + `data-class` for accent vs muted. Multi-state: a 2px color dot. Gray idle, orange in-flight, green done, red failed. hydra campaign progress uses that mapping.

## Two-column pages

```html
<div class="grid grid-cols-1 lg:grid-cols-12 gap-6">
    <div class="lg:col-span-8">...</div>
    <div class="lg:col-span-4 space-y-6">...</div>
</div>
```

Cards: `<div class="card"><header>...<section>...</section><footer>...</footer></div>`.

Collapsible: `data-show` on `<section>` only, never on the card. Otherwise the toggle disappears.

## Breadcrumbs

Dashboard → Items → current. Index depth 2, create/details 3, edit 4.

## Message stack

Every full page, in order:

1. Flash from session
2. Server `errors` on the page record
3. `<div id="sse-message-container"></div>`

## Notification choice

| Context | Success | Error |
|---------|---------|-------|
| Redirect after create/edit | session flash | errors on the form page |
| SSE fragment | toast on `#toaster` | message in `#sse-message-container` |
| Full page GET | n/a | errors on the page |

## Delete dialog

`<dialog class="dialog">`. Cancel closes it. Confirm POSTs the delete path. Click on backdrop (`evt.target === el`) closes.

## Danger zone

Same collapsible card, red border, `showDangerZone` signal.
