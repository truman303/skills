# Architecture patterns

> Placeholders: `pkg` is the Java package. See SKILL.md.

## Package layout

Organize by feature. A feature package holds everything about one aggregate: the domain record, its store, its routes and its page records.

```
pkg/
├── App.java                  # composition root
├── Result.java
├── ErrorDetail.java
├── DomainEvents.java         # only when a feature raises events
├── web/                      # HTTP kit used by every feature
│   ├── JavalinResponseAdapter.java
│   ├── Sse.java
│   ├── Signals.java
│   ├── TableState.java
│   ├── Message.java
│   ├── Templates.java
│   ├── SessionAuth.java
│   └── ExceptionMapping.java
└── features/
    ├── auth/
    │   ├── AuthRoutes.java
    │   └── UserStore.java
    ├── dashboard/
    │   └── DashboardRoutes.java
    └── items/
        ├── Item.java         # aggregate root
        ├── ItemId.java       # typed id
        ├── ItemForm.java     # posted strings, parsed to types
        ├── ItemStore.java    # Jdbi
        ├── ItemPages.java    # page records for the templates
        └── ItemRoutes.java
```

Templates live in `src/main/jte/{feature}/`, outside the Java tree.

There is no `controllers/`, `services/` or `repositories/` package that spans the app. To change how items work you open one folder.

## Who calls whom

```
browser  ->  ItemRoutes  ->  ItemForm.parse()   strings to types
                         ->  Item.create(...)   the rules
                         ->  ItemStore          SQL
                         ->  ItemPages          what the template prints
                         ->  JTE template or Sse
```

- Routes know about HTTP, forms, sessions and templates. They hold no business rules.
- The aggregate knows the rules. It does not know about HTTP, SQL or templates.
- The store knows SQL. It returns aggregates and takes aggregates.
- Templates know page records.

A GET reads and a POST writes. That split is the routing table, and it needs no command objects, handlers or bus on top. When a write grows past load, change, save, extract a service class in the same package. See [domain-modeling.md](domain-modeling.md).

## `Result`

Expected failures are values. Validation, a missing row, a broken rule: each returns `Result.Err` and the route decides how to show it.

```java
package pkg;

import java.util.List;
import java.util.function.Function;

public sealed interface Result<T> {
    record Ok<T>(T value) implements Result<T> {}

    record Err<T>(List<ErrorDetail> errors) implements Result<T> {
        public Err {
            errors = List.copyOf(errors);
        }
    }

    static <T> Result<T> ok(T value) {
        return new Ok<>(value);
    }

    static <T> Result<T> err(String code, String message) {
        return new Err<>(List.of(new ErrorDetail(code, message)));
    }

    static <T> Result<T> err(List<ErrorDetail> errors) {
        return new Err<>(errors);
    }

    default <R> Result<R> flatMap(Function<T, Result<R>> next) {
        return switch (this) {
            case Ok<T>(T value) -> next.apply(value);
            case Err<T>(List<ErrorDetail> errors) -> new Err<>(errors);
        };
    }
}
```

```java
package pkg;

public record ErrorDetail(String code, String message) {}
```

Consume it with a `switch`. The compiler insists on both cases:

```java
switch (result) {
    case Result.Ok<Item>(Item item) -> {
        store.insert(item);
        ctx.redirect("/items");
    }
    case Result.Err<Item>(List<ErrorDetail> errors) ->
            ctx.render("items/create.jte", Map.of("page", formPage(ctx, "", form, errors)));
}
```

Chain steps with `flatMap`. The first failure skips the rest:

```java
Result<Item> result = form.parse()
        .flatMap(v -> Item.create(v.name(), v.price(), v.active(), clock))
        .flatMap(this::nameIsFree);
```

| Kind of failure | Mechanism |
|-----------------|-----------|
| Validation, not found, business rule | `Result.Err`, shown as a message |
| A save that lost a race (stale version) | `Result.Err` |
| Database down, bug, disk full | Exception, caught by the handler in [javalin-app.md](javalin-app.md) |

## Domain code

Aggregates, typed ids, form records, stores and domain events are in [domain-modeling.md](domain-modeling.md). The short version:

- The aggregate root is a record. A static factory and methods on the root return `Result`.
- Ids are typed records, such as `record ItemId(UUID value)`.
- A form record turns posted strings into types before the aggregate sees them.
- One store per aggregate, saving the whole aggregate in one transaction.
- Domain events only when something consumes them.

## Persistence

Jdbi runs the SQL each store writes out. There is no ORM, so nothing is loaded lazily and nothing is saved unless a store method saves it.

- `jdbi.withHandle` for reads, `jdbi.useHandle` for single writes, `jdbi.inTransaction` when a save touches more than one table.
- Map rows by hand in the store.
- `timestamptz` columns, `Instant` in Java. `numeric` columns, `BigDecimal` in Java.
- Flyway runs migrations at startup. One `V00n__name.sql` per change. Never edit a migration that has shipped.

## The composition root

`App.java` builds every object and passes each its dependencies through the constructor. There is no container, no annotations and no classpath scanning. The whole wiring is one method. See [javalin-app.md](javalin-app.md).

## How Datastar is used

The server holds the state and renders the HTML. The browser shows it.

- State lives on the server. A signal holds what the user is typing or toggling, plus the few values the server needs back, such as the table's page number.
- The server answers a Datastar action with HTML. It does not send JSON for the browser to template.
- Patch a whole fragment. Send the complete table, not one changed row. Morphing works out the difference and keeps focus and scroll position.
- One fragment template serves both the first page load and every later patch, so the two cannot disagree.
- Links navigate between pages with `<a href>`. Buttons act within a page with `data-on:click`. The browser owns history.
- Show that work is in progress with `data-indicator`. Do not guess the result in the browser.
- Reach for a new signal last. If the server can render it, render it.

Details and code: [datastar-sse.md](datastar-sse.md) and [ui-component-patterns.md](ui-component-patterns.md).

## What goes where

| Interaction | Mechanism |
|-------------|-----------|
| Moving between pages | `<a href>`, full page GET |
| Create and edit forms | Plain form POST, redirect, flash message |
| Table search, paging, page size | Signals plus `@get` of the table fragment |
| Delete from a table row | `@post`, then patch the table and append a toast |
| Progress of something running | `data-init` opens a live SSE view |
| Open or close a dialog, toggle a section | Signal or plain DOM call in `data-on:click` |
| Rates and time-series | Prometheus and Grafana. See [observability.md](observability.md) |
