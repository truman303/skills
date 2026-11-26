# Javalin app

> Placeholders: `pkg` is the Java package. See SKILL.md.

`App.java` is the composition root. It builds the data source, the template engine and every route class, wires them together by hand and starts Javalin. No container, no annotations.

## `App.java`

```java
package pkg;

import com.zaxxer.hikari.HikariConfig;
import com.zaxxer.hikari.HikariDataSource;
import gg.jte.ContentType;
import gg.jte.TemplateEngine;
import gg.jte.resolve.DirectoryCodeResolver;
import io.javalin.Javalin;
import io.javalin.http.staticfiles.Location;
import io.javalin.rendering.template.JavalinJte;
import java.nio.file.Path;
import java.time.Clock;
import org.eclipse.jetty.ee10.servlet.SessionHandler;
import org.eclipse.jetty.http.HttpCookie;
import org.flywaydb.core.Flyway;
import org.jdbi.v3.core.Jdbi;
import pkg.features.auth.AuthRoutes;
import pkg.features.dashboard.DashboardRoutes;
import pkg.features.items.ItemRoutes;
import pkg.features.items.ItemStore;
import pkg.web.ExceptionMapping;
import pkg.web.SessionAuth;
import pkg.web.Templates;

public final class App {
    public static void main(String[] args) {
        HikariConfig hikari = new HikariConfig();
        hikari.setJdbcUrl(env("DATABASE_URL", "jdbc:postgresql://localhost:5432/myapp"));
        hikari.setUsername(env("DB_USER", "myapp"));
        hikari.setPassword(env("DB_PASSWORD", ""));
        HikariDataSource ds = new HikariDataSource(hikari);

        Flyway.configure().dataSource(ds).load().migrate();
        Jdbi jdbi = Jdbi.create(ds);
        Clock clock = Clock.systemUTC();

        boolean dev = Boolean.parseBoolean(env("JTE_DEV", "true"));
        TemplateEngine engine = dev
                ? TemplateEngine.create(new DirectoryCodeResolver(Path.of("src/main/jte")), ContentType.Html)
                : TemplateEngine.createPrecompiled(ContentType.Html);
        Templates templates = new Templates(engine);

        ItemStore itemStore = new ItemStore(jdbi);
        AuthRoutes auth = new AuthRoutes(jdbi, clock);
        DashboardRoutes dashboard = new DashboardRoutes(itemStore);
        ItemRoutes items = new ItemRoutes(itemStore, clock, templates);

        Javalin app = Javalin.create(config -> {
            config.concurrency.useVirtualThreads = true;
            config.fileRenderer(new JavalinJte(engine));
            config.staticFiles.add("/public", Location.CLASSPATH);
            config.jetty.modifyServletContextHandler(handler -> {
                SessionHandler sessions = new SessionHandler();
                sessions.setHttpOnly(true);
                sessions.setSameSite(HttpCookie.SameSite.LAX);
                handler.setSessionHandler(sessions);
            });
            ExceptionMapping.install(config.routes, templates);
            SessionAuth.install(config.routes, templates);
            auth.register(config.routes);
            dashboard.register(config.routes);
            items.register(config.routes);
            config.routes.get("/", ctx -> ctx.redirect("/dashboard"));
            config.routes.get("/health", ctx -> ctx.result("ok"));
        });

        Runtime.getRuntime().addShutdownHook(new Thread(app::stop));
        app.start(Integer.parseInt(env("UI_PORT", "8080")));
    }

    private static String env(String key, String fallback) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? fallback : value;
    }
}
```

What to know about Javalin 7:

- Routes are registered inside `Javalin.create(config -> { ... })` through `config.routes`. The `app.get(...)` style from older versions is gone.
- A route class takes `io.javalin.router.JavalinDefaultRoutingApi` in its `register` method. The type has no generic parameter.
- `config.concurrency.useVirtualThreads = true` gives each request a virtual thread. Live SSE views depend on it.
- Sessions run on a Jetty `SessionHandler` from `org.eclipse.jetty.ee10.servlet`, installed as shown. The cookie flags are set on it.

## Template engine

One `TemplateEngine` serves both full pages (through `JavalinJte` and `ctx.render`) and fragments (through `Templates.render`).

| `JTE_DEV` | Engine | Behaviour |
|-----------|--------|-----------|
| `true` (default) | `DirectoryCodeResolver(Path.of("src/main/jte"))` | Reads `.jte` files from disk and recompiles on change. Edit, refresh. |
| `false` | `TemplateEngine.createPrecompiled` | Uses the classes the Gradle plugin's `generate()` compiled into the jar. No source files needed. |

The dev path is relative to the working directory. `./gradlew run` starts in the project directory, so `src/main/jte` resolves. If the app is a module inside a larger build, point at the module: `Path.of("ui/src/main/jte")`.

Set `JTE_DEV=false` in any packaged or deployed run.

## `SessionAuth`

One before-handler guards every route that is not public. It covers three things: who is signed in, where to send people who are not, and whether a state-changing request really came from this app.

```java
package pkg.web;

import io.javalin.http.Context;
import io.javalin.http.ForbiddenResponse;
import io.javalin.http.HandlerType;
import io.javalin.router.JavalinDefaultRoutingApi;
import java.net.URI;
import java.util.UUID;

public final class SessionAuth {
    public static final String USER = "user";
    public static final String CSRF = "csrf";

    private SessionAuth() {}

    public static void install(JavalinDefaultRoutingApi routes, Templates templates) {
        routes.beforeMatched(ctx -> {
            if (isPublic(ctx)) {
                return;
            }
            if (ctx.sessionAttribute(USER) == null) {
                if (Sse.isDatastar(ctx)) {
                    // a fetch would follow a 302 and throw the login page away, so send the browser there
                    Sse.open(ctx, templates).redirect("/login");
                } else {
                    ctx.redirect("/login");
                }
                ctx.skipRemainingHandlers();
                return;
            }
            if (changesState(ctx) && !csrfOk(ctx)) {
                throw new ForbiddenResponse("This request did not come from the app. Reload the page and try again.");
            }
        });
    }

    public static void establish(Context ctx, String username) {
        ctx.req().getSession(true);
        ctx.req().changeSessionId();
        ctx.sessionAttribute(USER, username);
        ctx.sessionAttribute(CSRF, UUID.randomUUID().toString());
    }

    public static String userName(Context ctx) {
        String name = ctx.sessionAttribute(USER);
        return name == null ? "" : name;
    }

    public static String csrfToken(Context ctx) {
        String token = ctx.sessionAttribute(CSRF);
        return token == null ? "" : token;
    }

    /**
     * A plain form sends the hidden csrf field. A Datastar action sends the Datastar-Request
     * header, which a cross-site form cannot set and a cross-site fetch cannot send without a
     * CORS preflight this app never answers. The token stays out of signals because Datastar
     * puts every signal in the query string of a GET.
     */
    private static boolean csrfOk(Context ctx) {
        if (Sse.isDatastar(ctx)) {
            return sameOrigin(ctx);
        }
        String expected = ctx.sessionAttribute(CSRF);
        return expected != null && expected.equals(ctx.formParam("csrf"));
    }

    private static boolean sameOrigin(Context ctx) {
        String origin = ctx.header("Origin");
        if (origin == null) {
            return true;
        }
        try {
            return URI.create(origin).getAuthority().equals(ctx.host());
        } catch (RuntimeException e) {
            return false;
        }
    }

    private static boolean changesState(Context ctx) {
        HandlerType method = ctx.method();
        return method == HandlerType.POST
                || method == HandlerType.PUT
                || method == HandlerType.PATCH
                || method == HandlerType.DELETE;
    }

    private static boolean isPublic(Context ctx) {
        String path = ctx.path();
        return path.equals("/login")
                || path.equals("/health")
                || path.startsWith("/css/")
                || path.startsWith("/js/")
                || path.startsWith("/fonts/")
                || path.startsWith("/images/");
    }
}
```

How each piece behaves:

- **Not signed in, normal request.** Redirect to `/login`. `skipRemainingHandlers()` makes sure the route itself never runs, so no data is read or written for an anonymous caller.
- **Not signed in, Datastar request.** `sse.redirect("/login")` makes the browser navigate. This is what a user with an expired session sees when they click a pager button.
- **Signing in.** `AuthRoutes` calls `SessionAuth.establish` after checking the password. `changeSessionId()` gives the session a new id so one planted before login is useless.
- **Signing out.** `ctx.req().getSession().invalidate()` then redirect to `/login`.

### CSRF

Two kinds of state-changing request reach the server, and each proves its origin differently.

| Request | Proof | In the template |
|---------|-------|-----------------|
| Plain form POST | A hidden `csrf` field equal to the token in the session | `<input type="hidden" name="csrf" value="${csrfToken}">` in every form |
| Datastar `@post`, `@put`, `@patch`, `@delete` | The `Datastar-Request` header, plus an `Origin` that matches the host when the browser sends one | Nothing |

Another site can make a browser submit a form to this app, but it cannot add a custom header to that request. A cross-site `fetch` that tries to set the header triggers a CORS preflight, and this app does not answer preflights. So the header is the proof. Never enable CORS on this app without replacing this check.

Do not put the token in a signal. Datastar sends every signal with every action, and for `@get` they travel in the query string, which ends up in access logs and browser history.

The session cookie is `HttpOnly` and `SameSite=Lax`, set in `App.java`. Behind TLS, also call `sessions.setSecureCookies(true)`.

Rules that follow:

- Every `<form method="post">` contains the hidden `csrf` field. A form without it gets a 403.
- A GET never changes anything. The check does not cover GET.
- `/login` is public, so its POST is not checked. It has no session to protect yet.

## `ExceptionMapping`

Expected failures are `Result.Err` values and never arrive here. This catches the rest.

```java
package pkg.web;

import io.javalin.router.JavalinDefaultRoutingApi;
import java.util.List;
import java.util.Map;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public final class ExceptionMapping {
    private static final Logger LOG = LogManager.getLogger(ExceptionMapping.class);

    private ExceptionMapping() {}

    public static void install(JavalinDefaultRoutingApi routes, Templates templates) {
        routes.exception(Exception.class, (e, ctx) -> {
            LOG.error("unhandled {} {}", ctx.method(), ctx.path(), e);
            if (Sse.isDatastar(ctx)) {
                Sse.open(ctx, templates).messages(List.of(
                        new Message("error", "Something went wrong", List.of("Try again. If it keeps failing, check the server log."))));
                return;
            }
            ctx.status(500).render("error.jte", Map.of("title", "Error"));
        });
    }
}
```

A Datastar request gets a message patched into `#messages`, because a 500 page would be ignored and the click would look dead. A normal request gets the error page.

`error.jte` does not use the layout. If the layout is what failed, the error page still renders:

```html
@param String title

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>${title}</title>
    <link rel="stylesheet" href="/css/tailwind-output.css">
</head>
<body class="min-h-screen grid place-items-center">
    <div class="card max-w-md">
        <header><h2>Something went wrong</h2></header>
        <section><p class="text-sm text-muted-foreground">The error has been logged. <a class="underline" href="/">Go back to the start.</a></p></section>
    </div>
</body>
</html>
```

Never show the exception message or a stack trace to the user. Log it.

## Rendering

A full page:

```java
ctx.render("items/index.jte", Map.of("page", page));
```

Pass one page record under the name `page`. The template declares `@param IndexPage page` and the compiler checks every field it touches.

A fragment for a patch goes through `Sse`, which renders with `Templates`. See [datastar-sse.md](datastar-sse.md).

## Route order

Register `/items/new` and `/items/table` before `/items/{id}`, so that `new` and `table` are never read as ids.

## Adding a feature

1. Construct its store and its routes class in `App.main`.
2. Call `feature.register(config.routes)` next to the others.
3. Add a nav link to the layout and a card to the dashboard.
