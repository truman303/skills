# JTE templates

> Placeholders: `MyApp` is the display name, `pkg` the Java package. See SKILL.md.

Templates live in `src/main/jte`. A subdirectory is a namespace: `layout/page.jte` is called as `@template.layout.page(...)`.

A template's `@param` lines are compiled Java. A wrong type or a misspelled accessor fails the build. Tell the user to install the IntelliJ jte plugin so those errors show in the editor.

## The layout

A layout takes the page body as a `gg.jte.Content` parameter. This is the sidebar shell, the default.

`layout/page.jte`:

```html
@import gg.jte.Content
@param String title
@param String userName
@param String csrfToken
@param String currentPage
@param Content content

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${title} - MyApp</title>
    <script>
        (() => {
            try {
                const stored = localStorage.getItem('themeMode');
                const dark = stored ? stored === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
                document.documentElement.classList.toggle('dark', dark);
            } catch (_) {}
        })();
    </script>
    <script type="module" src="/js/basecoat.all.min.js"></script>
    <script type="module" src="/js/datastar.js"></script>
    <link rel="stylesheet" href="/css/tailwind-output.css">
</head>
<body>
    <aside class="sidebar" data-side="left" aria-hidden="false">
        <nav aria-label="Main navigation">
            <header class="p-8 m-3">
                <h1 class="text-xl font-bold">MyApp</h1>
            </header>
            <section class="scrollbar ml-1">
                <ul>
                    <li><a href="/dashboard" data-ignore-current aria-current="${currentPage.equals("Dashboard") ? "page" : "false"}">Dashboard</a></li>
                    <li><a href="/items" data-ignore-current aria-current="${currentPage.equals("Items") ? "page" : "false"}">Items</a></li>
                </ul>
            </section>
        </nav>
    </aside>
    <main class="sidebar-content min-h-screen">
        <header class="border-b border-border px-6 py-4">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-3">
                    <button type="button" class="btn-icon-outline" aria-label="Toggle sidebar"
                            data-on:click="document.dispatchEvent(new CustomEvent('basecoat:sidebar'))">
                        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><line x1="4" x2="20" y1="6" y2="6"/><line x1="4" x2="20" y1="12" y2="12"/><line x1="4" x2="20" y1="18" y2="18"/></svg>
                    </button>
                    <h2 class="text-lg font-semibold">${title}</h2>
                </div>
                <div class="flex items-center gap-3">
                    <button type="button" class="btn-icon-outline" aria-label="Toggle dark mode"
                            data-on:click="localStorage.setItem('themeMode', document.documentElement.classList.toggle('dark') ? 'dark' : 'light')">
                        <svg class="dark:hidden" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12 3a6 6 0 0 0 9 9 9 9 0 1 1-9-9Z"/></svg>
                        <svg class="hidden dark:block" xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2"/><path d="M12 20v2"/><path d="m4.93 4.93 1.41 1.41"/><path d="m17.66 17.66 1.41 1.41"/><path d="M2 12h2"/><path d="M20 12h2"/><path d="m6.34 17.66-1.41 1.41"/><path d="m19.07 4.93-1.41 1.41"/></svg>
                    </button>
                    @template.notifications.bell()
                    <span class="text-sm text-muted-foreground">${userName}</span>
                    <form method="post" action="/logout">
                        <input type="hidden" name="csrf" value="${csrfToken}">
                        <button type="submit" class="btn-sm-outline">Log out</button>
                    </form>
                </div>
            </div>
        </header>
        <div class="p-6">${content}</div>
        <footer class="border-t border-border px-6 py-4 text-center text-sm text-muted-foreground">MyApp</footer>
    </main>
    <div id="toaster" class="toaster" data-align="end"></div>
    <script src="/js/site.js"></script>
</body>
</html>
```

Notes on the layout:

- The inline script in `<head>` sets the `dark` class before the first paint, so a dark-mode user never sees a white flash.
- `tailwind-output.css` is the only stylesheet. It is `site.css` compiled, and `site.css` imports Tailwind, Basecoat and the theme. Do not link `basecoat.css` or `theme.css` directly. They contain Tailwind directives a browser cannot read.
- The dark-mode toggle needs no signal. It flips a class and stores the choice. The moon shows in light mode and the sun in dark mode through `dark:hidden` and `hidden dark:block`.
- `<body>` declares no signals. The user's name and the page title are printed by the server. A signal holding them would add nothing, and text pasted into a `data-signals` object breaks on the first apostrophe.
- `#toaster` is where SSE toasts are appended. Every page gets one through the layout.
- Every sidebar link carries `data-ignore-current`. Without it Basecoat's sidebar script sets `aria-current` itself, by comparing each link's path with the address bar, and it removes the server's value. `/items/new` is not `/items`, so the Items link would lose its highlight on the create and edit pages. With the attribute the server's `currentPage` decides.
- The first button in the top bar opens and closes the sidebar. On a narrow screen the sidebar starts closed, and this button is the only way to reach the navigation.
- `@template.notifications.bell()` is the notification bell. It takes no parameters and fills itself over SSE. See [notifications.md](notifications.md).
- Log out is a form, because it changes state and needs the CSRF field.

A page calls the layout and passes its body as a content block between `` @` `` and `` ` ``:

```html
@import pkg.features.items.ItemPages.IndexPage
@param IndexPage page

@template.layout.page(
    title = "Items",
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Items",
    content = @`
        <div> ... </div>
    `
)
```

Use named arguments on `@template` calls. Complete pages are in [crud-pages.md](crud-pages.md).

## Other shells

Ask which one during discovery. Only the layout file differs.

**Top nav.** Remove the `<aside>` and the sidebar button. Put the brand and the section links in a `<nav class="border-b border-border">` across the top, with the dark-mode button, the bell, user name and log out at the right. Put the content in `<main class="max-w-7xl mx-auto p-6">`.

**Minimal header.** A thin header with the app name, dark-mode button, the bell and log out. No section links. Pages link to each other from their own content. Suits a single-purpose app.

**Landing** (`layout/landing.jte`), for `/login`. No sidebar and no header. It links `landing.css` after `tailwind-output.css` and centres one card. See [login-page.md](login-page.md).

## Fragments

A fragment is a template whose root element has an `id`. It is used two ways:

- A page includes it: `@template.items.table(page = page)`.
- An SSE handler renders it alone and patches it over the element with the same id: `sse.patch("items/table.jte", Map.of("page", page))`.

Because both paths run the same file, the first render and every later patch produce the same markup.

Shared fragments live in `src/main/jte/fragments/`: `messages.jte` and `toast.jte`. Their source is in [crud-pages.md](crud-pages.md). The bell's fragments live in `src/main/jte/notifications/`.

## What `${}` prints

| Type | Result |
|------|--------|
| `String` | Printed, HTML-escaped for where it sits (text or attribute) |
| `int`, `long`, `boolean`, `BigDecimal` and other numbers | Printed |
| `gg.jte.Content` | Rendered |
| `UUID`, `Instant`, typed ids, most other objects | Compile error |

So convert in the page record. `ItemRow` holds `String id` and `String created`, already formatted. Templates then stay free of formatting code.

Escaping is automatic and depends on context. A name such as `Mike's "lunch" <b>special</b>` is safe in text and in an attribute value. That is also why `data-signals="${page.signals()}"` works: the JSON's quotes are escaped for the attribute and the browser turns them back.

## Syntax that is easy to get wrong

**Datastar actions are written as they are.** `@get('/items/table')`, `@post(...)`, `@put`, `@patch`, `@delete`, `@peek`, `@setAll`, `@toggleAll` all pass through JTE untouched. Do not double the `@`. JTE has no `@@` escape, so `@@get` reaches the browser as `@@get`, Datastar cannot parse it, and the handler does nothing without any error on the server.

**JTE claims `@if`, `@else` and `@for` as prefixes.** Body text such as `@format` or `@iffy` fails to compile with "Missing @endfor" or "Missing @endif". Email addresses and words such as `@media` are fine. When literal text must start with one of those, write `${"@"}format`, or wrap the passage in `@raw` and `@endraw`.

**`$name` is Datastar, `${...}` is JTE.** `$items.page` passes through. `${page.table().page()}` is evaluated on the server. Both can sit in one attribute:

```html
data-on:click="$items.page = ${page.table().page() + 1}; @get('/items/table')"
```

**Only server-made numbers and ids go inside a Datastar expression.** Never user text. `data-on:click="$name = '${row.name()}'"` breaks on an apostrophe and lets a crafted name run script. Put the text in a `data-*` attribute and read it with `el.dataset`. See the delete button in [crud-pages.md](crud-pages.md).

**Boolean attributes take a boolean.** `disabled="${!page.hasNext()}"` and `checked="${form.active()}"` print the bare attribute or nothing.

**Ternaries work inside attributes**, including string literals with double quotes:

```html
<span class="${row.active() ? "badge-secondary" : "badge-outline"}">
```

**A local variable** is declared with `!{var current = currentPage.equals("Items");}`.

**Control flow is Java.** `@if(page.rows().isEmpty())`, `@elseif(...)`, `@else`, `@endif`, `@for(ItemRow row : page.rows())`, `@endfor`.

## Keep templates dumb

A template prints a page record. It does not query, format dates, or decide business rules. If a template needs a value, add an accessor to the page record, such as `IndexPage.hasNext()`.

## Dev and production

In dev (`JTE_DEV=true`) the engine reads `.jte` files from disk, so a template change shows on the next refresh without a restart. A Java change still needs a restart.

The Gradle plugin's `generate()` compiles every template during the build. A template that does not compile fails `./gradlew build`, and the packaged app runs with `JTE_DEV=false` on the precompiled classes. See [javalin-app.md](javalin-app.md).
