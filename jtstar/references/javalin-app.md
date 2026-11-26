# Javalin app (composition root)

## Virtual threads

```java
Javalin app = Javalin.create(config -> {
    config.concurrency.useVirtualThreads = true;
    config.fileRenderer(dev
            ? new JavalinJte(JavalinJte.directoryTemplateEngine())
            : new JavalinJte());
    config.staticFiles.add("/public", Location.CLASSPATH);
    config.jetty.modifyServletContextHandler(handler -> {
        SessionHandler sessions = new SessionHandler();
        sessions.setHttpOnly(true);
        handler.setSessionHandler(sessions);
    });
});
```

Dev detection: `boolean dev = Boolean.parseBoolean(env("JTE_DEV", "true"));`. Directory engine hot-reloads `src/main/jte`. Production: `new JavalinJte()` (classpath, from `generate()`).

When the module is a Gradle subproject, `directoryTemplateEngine` must point at `hes-ui/src/main/jte` (or `src/main/jte` from that project dir). Pass an explicit path if the working directory is the repo root:

```java
JavalinJte.directoryTemplateEngine(Path.of("hes-ui/src/main/jte"))
```

## App.java (greenfield)

```java
package pkg;

import io.javalin.Javalin;
import org.flywaydb.core.Flyway;
import pkg.features.auth.AuthRoutes;
import pkg.features.dashboard.DashboardRoutes;
import pkg.features.items.ItemRoutes;
import pkg.web.ExceptionMapping;
import pkg.web.SessionAuth;

public final class App {
    public static void main(String[] args) {
        var ds = Datasource.fromEnv();
        Flyway.configure().dataSource(ds).load().migrate();
        var jdbi = JdbiFactory.create(ds);
        var clock = java.time.Clock.systemUTC();

        AuthRoutes auth = new AuthRoutes(jdbi, clock);
        DashboardRoutes dashboard = new DashboardRoutes(jdbi);
        ItemRoutes items = new ItemRoutes(jdbi, clock);

        Javalin javalin = Javalin.create(/* config above */);
        ExceptionMapping.install(javalin);
        SessionAuth.install(javalin);          // redirects to /login
        auth.register(javalin);
        dashboard.register(javalin);
        items.register(javalin);
        javalin.get("/", ctx -> ctx.redirect("/dashboard"));

        int port = Integer.parseInt(env("UI_PORT", "8080"));
        javalin.start(port);
    }
}
```

No DI framework. Each `*Routes` class takes stores in its constructor. That is the whole container.

## Sessions

```java
public final class SessionAuth {
    public static final String USER = "user";

    public static void install(Javalin app) {
        app.beforeMatched(ctx -> {
            if (isPublic(ctx)) return;
            if (ctx.sessionAttribute(USER) == null) {
                ctx.redirect("/login");
            }
        });
    }

    private static boolean isPublic(Context ctx) {
        String path = ctx.path();
        return path.equals("/login")
                || path.startsWith("/css/")
                || path.startsWith("/js/")
                || path.startsWith("/fonts/");
    }
}
```

Login POST verifies bcrypt, `ctx.sessionAttribute(USER, username)`, redirect `/dashboard`. Logout: `ctx.req().getSession().invalidate()`.

CSRF: store a UUID in the session at login, put it in the layout's `data-signals` as `csrfToken`. Every Datastar `@post` includes it because signals are sent. Reject POST if the signal does not match the session. Same-site Lax cookies make this belt-and-suspenders for an intranet app. Still do it on greenfield.

hydra stub auth: skip this class. See [attach-modular-monolith.md](attach-modular-monolith.md).

## Exception handler

```java
app.exception(Exception.class, (e, ctx) -> {
    LOG.error("unhandled {}", ctx.path(), e);
    if (Sse.isDatastar(ctx)) {
        Sse.patchMessage(ctx, "error", "Something went wrong");
        return;
    }
    ctx.status(500).render("error.jte", Map.of("title", "Error"));
});
```

Expected failures never get here. They are `Result.Err` rendered as inline messages. See [architecture-patterns.md](architecture-patterns.md).

## Rendering

Full page:

```java
ctx.render("items/index.jte", Map.of("page", page));
```

JTE `@param` types must match. Prefer a single page record over a bag of names:

```java
public record ItemIndexPage(
        String title,
        List<ItemRow> items,
        String searchQuery,
        int currentPage,
        int pageSize,
        int totalCount,
        List<ErrorDetail> errors
) {}
```

Fragment for SSE: render to a `StringOutput` (see [datastar-sse.md](datastar-sse.md)), then `PatchElements`.

## Health

Greenfield: `GET /health` → `ok`. Optional `GET /metrics` if you add a Prometheus registry. hydra attach: do not steal 9464.

## Shutdown

```java
Runtime.getRuntime().addShutdownHook(new Thread(javalin::stop));
```

On attach, `UiServer` is `AutoCloseable` and the existing shutdown hook closes it with everyone else.
