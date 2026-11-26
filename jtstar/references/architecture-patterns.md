# Architecture patterns

## Package layout

Organize by feature, not by `controller` / `service` / `repository` layers that span the app.

```
pkg/
├── App.java
├── Result.java
├── web/                      # HTTP kit used by every feature
│   ├── JavalinRequestAdapter.java
│   ├── JavalinResponseAdapter.java
│   ├── Sse.java
│   ├── SessionAuth.java
│   └── ExceptionMapping.java
├── features/
│   ├── auth/
│   │   ├── AuthRoutes.java
│   │   └── UserStore.java
│   ├── dashboard/
│   │   └── DashboardRoutes.java
│   └── items/
│       ├── Item.java         # record + validation
│       ├── ItemStore.java    # Jdbi
│       ├── ItemRoutes.java
│       └── ItemPages.java    # page records
```

Templates: `src/main/jte/{feature}/`. Not under `java/`.

hydra: `za.co.ipay.hydra.v3.ui.campaigns` etc. No `ItemStore`. Routes call ports passed into `UiServer`.

## Do not add MediatR

A Javalin handler calling `itemStore.insert(...)` is CQRS enough: GET reads, POST writes. A `CreateItemCommand` type plus a handler plus a bus is a second routing layer on top of the one you already have.

If a write grows (validate, insert, audit, emit), extract `ItemService` in the same package. Still no bus.

## `Result`

```java
public sealed interface Result<T> {
    record Ok<T>(T value) implements Result<T> {}
    record Err<T>(List<ErrorDetail> errors) implements Result<T> {
        Err(ErrorDetail error) { this(List.of(error)); }
    }

    static <T> Result<T> ok(T value) { return new Ok<>(value); }
    static <T> Result<T> err(String code, String message) {
        return new Err<>(new ErrorDetail(code, message));
    }

    default boolean isOk() { return this instanceof Ok<T>; }

    default <R> R match(Function<T, R> ok, Function<List<ErrorDetail>, R> err) {
        return switch (this) {
            case Ok<T>(var value) -> ok.apply(value);
            case Err<T>(var errors) -> err.apply(errors);
        };
    }
}

public record ErrorDetail(String code, String message) {}
```

Domain factories return `Result<Item>`. Routes `match` into a redirect or a re-rendered page with errors. Unexpected failures throw and hit the Javalin exception handler.

| Kind | Mechanism |
|------|----------|
| Validation, not found, rule | `Result.Err` |
| Unique constraint you expected | `Result.Err` (catch and map) |
| Pool exhausted, disk, bug | Exception |

## Domain records

```java
public record Item(UUID id, String name, boolean active, Instant createdAt, Instant updatedAt) {
    public static Result<Item> create(String name, boolean active, Clock clock) {
        if (name == null || name.isBlank()) return Result.err("Item.Name.Empty", "Name is required");
        if (name.length() > 100) return Result.err("Item.Name.TooLong", "Name max 100 characters");
        Instant now = clock.instant();
        return Result.ok(new Item(UUID.randomUUID(), name.trim(), active, now, now));
    }
}
```

Use `java.time.Clock`. Never `Instant.now()` in domain code. PostgreSQL `timestamptz` maps to `Instant`. Never `LocalDateTime` for stored timestamps.

Co-locate the store in the same package. Do not split `Item.java` into nine files because RazorStar's example did.

## Jdbi

```java
public final class ItemStore {
    private final Jdbi jdbi;
    public ItemStore(Jdbi jdbi) { this.jdbi = jdbi; }

    public List<Item> findPage(String q, int offset, int limit) {
        return jdbi.withHandle(h -> h.createQuery("""
                        select id, name, active, created_at, updated_at
                        from items
                        where name ilike :q
                        order by name
                        offset :offset limit :limit
                        """)
                .bind("q", "%" + q + "%")
                .bind("offset", offset)
                .bind("limit", limit)
                .mapTo(Item.class)
                .list());
    }

    public void insert(Item item) {
        jdbi.useHandle(h -> h.createUpdate("""
                        insert into items (id, name, active, created_at, updated_at)
                        values (:id, :name, :active, :createdAt, :updatedAt)
                        """)
                .bindMethods(item)
                .execute());
    }
}
```

Register `JavaTimePlugin` and a UUID column mapper on the `Jdbi` instance in the composition root. SQL stays visible. That is why this stack survives Citus.

hydra UI: no `ItemStore`. If you need a query the port does not expose, add the method on the published API in the owning module.

## Routes

```java
public final class ItemRoutes {
    private final ItemStore store;
    private final Clock clock;
    private final TemplateEngine jte;

    public void register(Javalin app) {
        app.get("/items", this::index);
        app.get("/items/table", this::table);
        app.get("/items/new", this::createForm);
        app.post("/items", this::create);
        app.get("/items/{id}", this::details);
        app.get("/items/{id}/edit", this::editForm);
        app.post("/items/{id}", this::update);
        app.post("/items/{id}/delete", this::delete);
    }
}
```

POST that succeeds: `ctx.redirect("/items")` (PRG). POST from Datastar that should stay on the page: patch table + toast.

## The tao of Datastar

Copied in spirit from RazorStar. The Datastar core team's opinions, not ours:

- Most state lives on the backend.
- Start with defaults.
- Patch elements and signals. The backend drives.
- Signals are for input and toggles, not a client-side model of the database.
- Morph. Fat morph is fine.
- SSE is the response type. Use the SDK.
- Templates keep HTML DRY.
- `<a href>` for navigation. Do not fake history.
- No optimistic UI. Use loading indicators.

## hydra-specific

The UI module must not `SpineBus.subscribe`. Consumer groups are a domain delivery knob. A UI group either competes with MDM/orchestration or fans out a third copy of every event into a browser thread. Read projections and in-memory services the composition root already has.

Grafana owns rates, queue depth, consumer lag. If you add a sparkline to a JTE card, you are in the wrong skill. See [observability.md](observability.md).
