# JTE templates

Templates live in `src/main/jte`. Subdirectories are packages: `layout/page.jte` is `@template.layout.page(...)`.

Install the IntelliJ jte plugin. `@param` is compiled Java. Wrong types fail the build, not at runtime.

## Page record in, Content block out

Layouts take `gg.jte.Content` for the body. Pages wrap themselves:

```
@import gg.jte.Content
@param String title
@param String userName
@param boolean authenticated
@param String currentPage
@param String csrfToken
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
                const isDark = stored ? stored === 'dark' : matchMedia('(prefers-color-scheme: dark)').matches;
                if (isDark) document.documentElement.classList.add('dark');
                window.initialThemeMode = isDark ? 'dark' : 'light';
            } catch (_) {}
        })();
    </script>
    <script type="module" src="/js/basecoat.all.min.js" defer></script>
    <script type="module" src="/js/datastar.js"></script>
    <link rel="stylesheet" href="/css/basecoat.css">
    <link rel="stylesheet" href="/css/tailwind-output.css">
    <link rel="stylesheet" href="/css/theme.css">
</head>
<body data-signals="{
        csrfToken: '${csrfToken}',
        loading: false,
        themeMode: window.initialThemeMode || 'light',
        user: { name: '${userName}', isAuthenticated: ${authenticated} },
        sidebarCollapsed: false,
        currentPage: '${title}'
    }">
    <aside class="sidebar" data-side="left" aria-hidden="false">
        <nav aria-label="Main navigation">
            <header class="p-8 m-3">
                <h1 class="text-xl font-bold">MyApp</h1>
            </header>
            <section class="scrollbar ml-1">
                <ul>
                    <li>
                        !{var dashCurrent = currentPage.equals("Dashboard") ? "page" : "false";}
                        <a href="/dashboard" aria-current="${dashCurrent}">Dashboard</a>
                    </li>
                </ul>
            </section>
        </nav>
    </aside>
    <main class="sidebar-content min-h-screen">
        <header class="border-b border-border px-6 py-4">
            <div class="flex items-center justify-between">
                <h2 class="text-lg font-semibold" data-text="$currentPage">${title}</h2>
                <div class="flex items-center gap-3">
                    <button type="button" class="btn btn-outline btn-sm text-foreground"
                            data-on:click="
                                $themeMode = $themeMode === 'dark' ? 'light' : 'dark';
                                document.documentElement.classList.toggle('dark');
                                localStorage.setItem('themeMode', $themeMode);"
                            aria-label="Toggle dark mode">Dark mode</button>
                    <span class="btn btn-ghost btn-sm" data-text="$user.name">${userName}</span>
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

Caller:

```
@import pkg.features.items.ItemIndexPage
@param ItemIndexPage page

@template.layout.page(
    title = page.title(),
    userName = page.userName(),
    authenticated = true,
    currentPage = "Items",
    csrfToken = page.csrfToken(),
    content = @`
        <div class="..."> ... ${page.title()} ... </div>
    `
)
```

`${}` only accepts String, primitives, enums, and `Content`. Call `.toString()` in the Java page record if you need to print an id. JTE will not call it for you.

For JSON inside `data-signals`, put the JSON together in Java (`page.signalsJson()`) and output it with care. A mismatched quote in `data-signals` is the usual blank-page bug.

Dark-mode button SVGs can be copied from the RazorStar layout if you want sun/moon icons. The class names matter more than the icons.

## Three shells

The block above is **sidebar**, the default, and what hydra should use. Same Basecoat classes as RazorStar.

**Top nav.** Drop the `aside`. Put brand + links in a top `nav.border-b`, content in `main.max-w-7xl.mx-auto`.

**Creative.** Header strip with app name, dark mode, profile. No section links. Pages navigate themselves.

Landing layout for `/login`: no sidebar. Include `landing.css`. Centered card. See [login-page.md](login-page.md).

## Fragments

A fragment is a template rendered to a string and patched by selector.

`items/table.jte` takes the same rows as the index page, but only the `<div id="items-table">...</div>` wrapper. The index page includes it:

```
@template.items.table(page = page)
```

SSE re-renders `items/table.jte` and patches `#items-table`. Morph keeps input focus.

Toasts: `fragments/toast.jte` patched onto `#toaster` with `ElementPatchMode.Append`.

Messages: `fragments/message.jte` into `#page-messages`.

## Hot reload

`JavalinJte.directoryTemplateEngine()` in dev. Change a `.jte`, refresh. Generated sources from the Gradle plugin still run in `./gradlew run` / tests, so CI compiles templates.

## Gotchas

- **`@` is JTE.** `@get`, `@post`, `@if` are all JTE's character. Datastar actions in a `.jte` file must be written `@@get('/items/table')` and `@@post('/items')`. JTE emits a single `@`. This is the same doubling Razor uses, for the same reason. Forgetting it is a compile error, not a runtime blank page.
- No implicit `toString()`. Convert in the record.
- `@if` / `@for` / `@endif` / `@endfor` are Java. `page.items().isEmpty()` works.
- Named parameters on `@template` calls. The IntelliJ plugin wants them.
- Keep templates dumb. No Jdbi in a `.jte`. If you need a format helper, put it on the record.
