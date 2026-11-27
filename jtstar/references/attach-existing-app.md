# Attach to an existing Java app

> Placeholders: `pkg` is the Java package. `ui` is the name used here for the new Gradle module.

Use this track when the app already exists and the job is to give it screens: a service, a batch system or a modular monolith with no web UI. Greenfield scaffolding does not apply. The host app keeps its database, its build and its way of starting.

The rest of the skill still applies unchanged: the `pkg.web` kit, the templates, the page shapes and the SSE patterns.

## What changes compared with greenfield

| Greenfield | Attach |
|------------|--------|
| New Gradle project | New module in the host's build |
| `App.java` is the composition root | The host's `main` constructs a `UiServer` and starts it |
| Docker Postgres, Flyway migrations | The host's database and schema tooling. No second database. |
| Users table and bcrypt login | Whatever the host uses for identity. See below. |
| The UI's features own aggregates and stores | Screens call services the host already has |

## Ask before building

1. Which module or class is the host's composition root, and how does it shut down?
2. Which services or query interfaces should the screens call? Ask for the public ones. If the screens need a query that does not exist, add it to the owning module's public API. Do not reach into its internals from the UI.
3. Which port should the UI listen on, and is any port already taken by the host?
4. How do users prove who they are today?
5. Does the host already publish metrics to Grafana or similar? If so, link to it. See [observability.md](observability.md).

## The module

```
ui/
├── build.gradle
├── src/main/java/pkg/ui/
│   ├── UiServer.java           # builds and starts Javalin
│   ├── web/                    # the kit from datastar-sse.md and javalin-app.md
│   ├── dashboard/DashboardRoutes.java
│   └── <screen>/<Screen>Routes.java
├── src/main/jte/
│   ├── layout/page.jte
│   ├── fragments/
│   └── <screen>/
└── src/main/resources/public/  # assets copied from the skill
```

`settings.gradle` in the host:

```groovy
include(':ui')
```

The root `build.gradle` declares the JTE plugin once so the module can apply it without a version:

```groovy
plugins {
    id 'gg.jte.gradle' version "${jteVer}" apply false
}
```

`ui/build.gradle`:

```groovy
plugins {
    id 'java-library'
    id 'gg.jte.gradle'
}

jte {
    generate()
}

dependencies {
    // the host modules whose public services the screens call
    implementation project(':orders-api')

    implementation "io.javalin:javalin:${javalinVer}"
    implementation "io.javalin:javalin-rendering-jte:${javalinVer}"
    implementation "gg.jte:jte:${jteVer}"
    implementation "dev.data-star:datastar-java-sdk-core:${datastarVer}"
}
```

Add `javalinVer`, `jteVer` and `datastarVer` wherever the host keeps its versions. Use the values in [project-scaffolding.md](project-scaffolding.md). Leave out Jdbi and Flyway unless the UI truly owns a table.

## `UiServer`

The host's composition root already holds the services. Pass them in.

```java
package pkg.ui;

import gg.jte.ContentType;
import gg.jte.TemplateEngine;
import gg.jte.resolve.DirectoryCodeResolver;
import io.javalin.Javalin;
import io.javalin.http.staticfiles.Location;
import io.javalin.rendering.template.JavalinJte;
import java.nio.file.Path;
import org.eclipse.jetty.ee10.servlet.SessionHandler;
import org.eclipse.jetty.http.HttpCookie;
import pkg.ui.web.ExceptionMapping;
import pkg.ui.web.SessionAuth;
import pkg.ui.web.Templates;

public final class UiServer implements AutoCloseable {
    private final Javalin app;
    private final int port;

    public UiServer(int port, boolean dev, OrderQueries orders /* and the other services the screens call */) {
        this.port = port;
        TemplateEngine engine = dev
                ? TemplateEngine.create(new DirectoryCodeResolver(Path.of("ui/src/main/jte")), ContentType.Html)
                : TemplateEngine.createPrecompiled(ContentType.Html);
        Templates templates = new Templates(engine);
        OrderRoutes orderRoutes = new OrderRoutes(orders, templates);

        this.app = Javalin.create(config -> {
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
            orderRoutes.register(config.routes);
            config.routes.get("/", ctx -> ctx.redirect("/orders"));
        });
    }

    public void start() {
        app.start(port);
    }

    @Override
    public void close() {
        app.stop();
    }
}
```

In the host's `main`:

```java
UiServer ui = new UiServer(Integer.parseInt(env("UI_PORT", "8080")), dev, orderQueries);
ui.start();
// close it wherever the host already closes its other resources
```

The dev template path is relative to the working directory. When the host starts from the repository root, the path includes the module name, as above.

## Dependency direction

The UI is a client of the host's modules. Nothing in the host depends on the UI.

- The UI depends on the public API of each module it shows: service interfaces, query interfaces and the records they return.
- The UI does not depend on another module's implementation classes, tables or message consumers.
- If the host has architecture tests, add the UI's package to them with exactly those two rules.

Screens follow the same shape as a greenfield feature with one substitution: where `ItemRoutes` calls `ItemStore`, an attached route calls the host's service. Page records still sit between the host's types and the templates.

## Do not join the host's messaging

If the host passes events between its modules over a bus or a queue, do not subscribe from the UI. A UI consumer either competes with a real one for messages or adds load that grows with open browser tabs. Read a projection or a query the host already keeps, and for a live view poll it on an interval as [datastar-sse.md](datastar-sse.md) shows.

## Sign-in

Pick the first that applies:

1. The host has an identity service. Call it from `AuthRoutes` in place of the bcrypt check, and keep `SessionAuth` as it is.
2. A reverse proxy in front of the app authenticates users. Read the header it sets, and have `SessionAuth` treat a request without it as not signed in.
3. Neither exists and this is an internal tool. Use a single shared password from the environment with the normal login page. Do not add a users table to the host's database for it. Tell the user this is a stopgap.

Never ship a UI that changes data with sign-in switched off.

## The notification bell

The layout in [jte-templates.md](jte-templates.md) includes the bell, and the bell needs a table of its own. An attached UI usually has no table, so pick the first that applies:

1. The host already keeps per-user notifications. Keep the bell and the routes from [notifications.md](notifications.md), and have the routes read and update through the host's service in place of `NotificationStore`.
2. The user wants the bell and agrees to one new table. Raise it as a schema change, then build the feature as written.
3. Otherwise remove `@template.notifications.bell()` from the layout and skip the feature.

## First screens

1. A dashboard with a few counts the host can already answer, plus links to the screens.
2. The one screen the user asked for. A list screen follows [crud-pages.md](crud-pages.md) with the host's query in place of the store. An action with progress follows the live view in [datastar-sse.md](datastar-sse.md). A screen with a form gets a Guidelines card, and its text states the rules the host's service enforces.

Get one screen in front of the user before building the second.

## Leave alone

- The host's existing HTTP endpoints and ports, including any metrics endpoint.
- The host's schema. If a screen needs its own table, raise that with the user first.
- The host's dependency choices. Do not add a DI container or an ORM as part of adding a UI.
