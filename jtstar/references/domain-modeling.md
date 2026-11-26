# Domain modeling

> Placeholders: `pkg` is the Java package. See SKILL.md.

How a feature's domain code is shaped: aggregates, entities, value objects, typed ids, the store, and domain events. The rules are short because Java 21 records and sealed types carry most of them.

## Vocabulary

| Term | Meaning here | In code |
|------|--------------|---------|
| Aggregate | A cluster of objects that changes as one unit and is saved in one transaction | A record plus the records nested in it |
| Aggregate root | The one object the rest of the app may hold and call | `Item`, `Order` |
| Entity | Has an identity that outlives changes to its fields | The root. Child rows such as `Order.Line` |
| Value object | Defined only by its values, with no identity | A small record: `Money`, `EmailAddress` |
| Typed id | An id that cannot be mixed up with another aggregate's id | `record ItemId(UUID value)` |
| Store | Loads and saves one aggregate | `ItemStore`, `OrderStore` |
| Domain event | A fact the aggregate reports after it changed | A record in a sealed `Event` interface |

## Rules

1. One aggregate per feature package to start with. `features/items/` owns `Item`.
2. Nothing outside the aggregate constructs or edits its parts. Callers go through a static factory or a method on the root, and each returns a `Result`.
3. An aggregate that exists is valid. All checks run in the factory and the methods, so no caller validates a second time.
4. One store per aggregate root. It saves the root and its children in one transaction. A store has no method that touches a child row alone.
5. Another aggregate is referenced by its typed id, never by holding the object.
6. The aggregate never sees a form, a `Context`, or a `String` that still needs parsing. A form record at the edge turns strings into types first.
7. A rule that needs the database, such as a unique name, cannot live on the aggregate. Put it next to the store call and return a `Result` there.
8. Domain code takes a `Clock`. It never calls `Instant.now()`.
9. Templates see page records, never the aggregate.
10. Add domain events only when something consumes them.

## Typed id

```java
package pkg.features.items;

import java.util.Optional;
import java.util.UUID;

public record ItemId(UUID value) {
    public static ItemId create() {
        return new ItemId(UUID.randomUUID());
    }

    /** Path params arrive as strings. An id that does not parse is the same as an id that does not exist. */
    public static Optional<ItemId> parse(String raw) {
        try {
            return Optional.of(new ItemId(UUID.fromString(raw)));
        } catch (IllegalArgumentException | NullPointerException e) {
            return Optional.empty();
        }
    }

    @Override
    public String toString() {
        return value.toString();
    }
}
```

`store.find(orderId)` on an `ItemStore` is now a compile error. The store unwraps with `id.value()` when binding and wraps again when mapping a row, so Jdbi needs no plugin or custom mapper.

`ItemId.parse(ctx.pathParam("id")).flatMap(store::find)` handles a garbage id and a missing row the same way, which is how the user experiences them.

## A simple aggregate

No children. The root is the whole aggregate.

```java
package pkg.features.items;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import pkg.ErrorDetail;
import pkg.Result;

/** Aggregate root. Every Item that exists went through create or change, so every Item is valid. */
public record Item(ItemId id, String name, BigDecimal price, boolean active, Instant createdAt, Instant updatedAt) {
    public static final int NAME_MAX = 100;

    public static Result<Item> create(String name, BigDecimal price, boolean active, Clock clock) {
        List<ErrorDetail> errors = check(name, price);
        if (!errors.isEmpty()) {
            return Result.err(errors);
        }
        Instant now = clock.instant();
        return Result.ok(new Item(ItemId.create(), name.trim(), price, active, now, now));
    }

    public Result<Item> change(String name, BigDecimal price, boolean active, Clock clock) {
        List<ErrorDetail> errors = check(name, price);
        if (!errors.isEmpty()) {
            return Result.err(errors);
        }
        return Result.ok(new Item(id, name.trim(), price, active, createdAt, clock.instant()));
    }

    private static List<ErrorDetail> check(String name, BigDecimal price) {
        List<ErrorDetail> errors = new ArrayList<>();
        if (name == null || name.isBlank()) {
            errors.add(new ErrorDetail("Item.Name.Empty", "Name is required."));
        } else if (name.trim().length() > NAME_MAX) {
            errors.add(new ErrorDetail("Item.Name.TooLong", "Name can be at most " + NAME_MAX + " characters."));
        }
        if (price == null || price.signum() < 0) {
            errors.add(new ErrorDetail("Item.Price.Negative", "Price cannot be negative."));
        }
        return errors;
    }
}
```

Records are immutable, so a change returns a new `Item`. The factory collects every problem before it answers, and the user fixes the form in one pass.

A record's canonical constructor is public, and the store uses it to rebuild an `Item` from a row. That is the one caller allowed to skip the factory, because the row was valid when it was written. Everything else calls `create` or `change`.

Error codes read `Aggregate.Field.Problem`. Messages are sentences the user can act on.

## The form record

The browser sends strings. The aggregate takes types. The form record sits between them and does only the conversion.

```java
package pkg.features.items;

import io.javalin.http.Context;
import java.math.BigDecimal;
import java.math.RoundingMode;
import pkg.Result;

/** What the browser posted, as strings, so the form can be shown again exactly as typed. */
public record ItemForm(String name, String price, boolean active) {
    /** The same fields once they have types. This is what the aggregate accepts. */
    public record Values(String name, BigDecimal price, boolean active) {}

    public static ItemForm blank() {
        return new ItemForm("", "", true);
    }

    public static ItemForm of(Item item) {
        return new ItemForm(item.name(), item.price().toPlainString(), item.active());
    }

    public static ItemForm from(Context ctx) {
        return new ItemForm(
                text(ctx.formParam("name")),
                text(ctx.formParam("price")),
                ctx.formParam("active") != null);
    }

    /** String to type only. Whether the values are acceptable is the aggregate's call. */
    public Result<Values> parse() {
        try {
            BigDecimal amount = new BigDecimal(price.trim()).setScale(2, RoundingMode.HALF_UP);
            return Result.ok(new Values(name, amount, active));
        } catch (NumberFormatException e) {
            return Result.err("ItemForm.Price.NotANumber", "Price must be a number, for example 12.50.");
        }
    }

    private static String text(String raw) {
        return raw == null ? "" : raw;
    }
}
```

The split is strict. "Is this text a number?" belongs to the form. "May a price be negative?" belongs to the aggregate. An aggregate with a `create(String priceRaw, ...)` signature has let the web layer in, and every other caller then has to format numbers as strings to use it.

The route chains the three steps:

```java
Result<Item> result = form.parse()
        .flatMap(v -> Item.create(v.name(), v.price(), v.active(), clock))
        .flatMap(this::nameIsFree);
```

`nameIsFree` is rule 7 in practice. It asks the store and returns `Result.err("Item.Name.Taken", ...)` or the item. Keep the unique index in the database as well. The check gives a friendly message, and the index is what holds when two requests race.

## The store

```java
package pkg.features.items;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.jdbi.v3.core.Jdbi;

/** The repository for the Item aggregate. One store per aggregate root. */
public final class ItemStore {
    private static final String COLUMNS = "id, name, price, active, created_at, updated_at";
    private final Jdbi jdbi;

    public ItemStore(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public int count(String search) {
        return jdbi.withHandle(h -> h.createQuery("select count(*) from items where name ilike :q")
                .bind("q", like(search))
                .mapTo(Integer.class)
                .one());
    }

    public List<Item> findPage(String search, int offset, int limit) {
        return jdbi.withHandle(h -> h.createQuery(
                        "select " + COLUMNS + " from items where name ilike :q order by lower(name), id offset :offset limit :limit")
                .bind("q", like(search))
                .bind("offset", offset)
                .bind("limit", limit)
                .map((rs, ctx) -> map(rs))
                .list());
    }

    public Optional<Item> find(ItemId id) {
        return jdbi.withHandle(h -> h.createQuery("select " + COLUMNS + " from items where id = :id")
                .bind("id", id.value())
                .map((rs, ctx) -> map(rs))
                .findOne());
    }

    public boolean nameTaken(String name, ItemId except) {
        return jdbi.withHandle(h -> h.createQuery(
                        "select exists (select 1 from items where lower(name) = lower(:name) and id <> :except)")
                .bind("name", name.trim())
                .bind("except", except.value())
                .mapTo(Boolean.class)
                .one());
    }

    public void insert(Item item) {
        jdbi.useHandle(h -> h.createUpdate("""
                        insert into items (id, name, price, active, created_at, updated_at)
                        values (:id, :name, :price, :active, :createdAt, :updatedAt)
                        """)
                .bind("id", item.id().value())
                .bind("name", item.name())
                .bind("price", item.price())
                .bind("active", item.active())
                .bind("createdAt", item.createdAt())
                .bind("updatedAt", item.updatedAt())
                .execute());
    }

    public void update(Item item) {
        jdbi.useHandle(h -> h.createUpdate("""
                        update items set name = :name, price = :price, active = :active, updated_at = :updatedAt
                        where id = :id
                        """)
                .bind("id", item.id().value())
                .bind("name", item.name())
                .bind("price", item.price())
                .bind("active", item.active())
                .bind("updatedAt", item.updatedAt())
                .execute());
    }

    public void delete(ItemId id) {
        jdbi.useHandle(h -> h.createUpdate("delete from items where id = :id")
                .bind("id", id.value())
                .execute());
    }

    private static String like(String search) {
        String term = search == null ? "" : search.trim()
                .replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_");
        return "%" + term + "%";
    }

    private static Item map(ResultSet rs) throws SQLException {
        return new Item(
                new ItemId(rs.getObject("id", UUID.class)),
                rs.getString("name"),
                rs.getBigDecimal("price"),
                rs.getBoolean("active"),
                rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                rs.getObject("updated_at", OffsetDateTime.class).toInstant());
    }
}
```

The migration:

```sql
create table items (
    id uuid primary key,
    name text not null,
    price numeric(12, 2) not null,
    active boolean not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);
create unique index items_name_key on items (lower(name));
```

Notes:

- Map rows by hand. It is six lines, it is where the typed id gets wrapped, and it needs no Jdbi plugin.
- `timestamptz` reads as `OffsetDateTime`, then `.toInstant()`. Store instants. Never `LocalDateTime`.
- `like` escapes `%` and `_`, so a search for `50%` finds names containing `50%` and not every row.
- Order by a stable key (`lower(name), id`). Without the tiebreaker, rows with equal names can swap pages between requests.
- Money is `numeric` in SQL and `BigDecimal` in Java.

## An aggregate with child entities

Use this shape when the feature has rows that only exist inside a parent: order lines, invoice items, checklist steps. It also shows a status workflow and domain events.

```java
package pkg.features.orders;

import java.math.BigDecimal;
import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import pkg.Result;

/**
 * Aggregate root with child entities. Lines exist only inside an order: nothing outside this
 * file adds, removes or edits one, and the store saves the order and its lines together.
 */
public record Order(
        OrderId id,
        String customer,
        Status status,
        List<Line> lines,
        int version,
        Instant createdAt,
        Instant updatedAt) {

    public static final int MAX_LINES = 50;

    public record OrderId(UUID value) {
        public static OrderId create() {
            return new OrderId(UUID.randomUUID());
        }

        public static Optional<OrderId> parse(String raw) {
            try {
                return Optional.of(new OrderId(UUID.fromString(raw)));
            } catch (IllegalArgumentException | NullPointerException e) {
                return Optional.empty();
            }
        }

        @Override
        public String toString() {
            return value.toString();
        }
    }

    public enum Status { DRAFT, SUBMITTED, CANCELLED }

    /** Child entity. Its identity is the line number, which only means something inside its order. */
    public record Line(int lineNo, String sku, int quantity, BigDecimal unitPrice) {
        public BigDecimal total() {
            return unitPrice.multiply(BigDecimal.valueOf(quantity));
        }
    }

    /** What happened, for anything outside the aggregate that cares. */
    public sealed interface Event {
        record Submitted(OrderId id, String customer, BigDecimal total, Instant at) implements Event {}

        record Cancelled(OrderId id, Instant at) implements Event {}
    }

    /** New state plus the events that change raised. Records cannot collect events as a side effect, so return them. */
    public record Outcome(Order order, List<Event> events) {}

    public Order {
        lines = List.copyOf(lines);
    }

    public static Result<Order> open(String customer, Clock clock) {
        if (customer == null || customer.isBlank()) {
            return Result.err("Order.Customer.Empty", "Customer is required.");
        }
        Instant now = clock.instant();
        return Result.ok(new Order(OrderId.create(), customer.trim(), Status.DRAFT, List.of(), 0, now, now));
    }

    public Result<Order> addLine(String sku, int quantity, BigDecimal unitPrice, Clock clock) {
        if (status != Status.DRAFT) {
            return Result.err("Order.NotDraft", "Only a draft order can be changed.");
        }
        if (lines.size() >= MAX_LINES) {
            return Result.err("Order.TooManyLines", "An order can have at most " + MAX_LINES + " lines.");
        }
        if (sku == null || sku.isBlank()) {
            return Result.err("Order.Line.Sku.Empty", "SKU is required.");
        }
        if (quantity < 1) {
            return Result.err("Order.Line.Quantity.NotPositive", "Quantity must be at least 1.");
        }
        if (unitPrice == null || unitPrice.signum() < 0) {
            return Result.err("Order.Line.Price.Negative", "Unit price cannot be negative.");
        }
        if (lines.stream().anyMatch(l -> l.sku().equalsIgnoreCase(sku.trim()))) {
            return Result.err("Order.Line.Sku.Duplicate", "SKU " + sku.trim() + " is already on this order.");
        }
        int nextNo = lines.stream().mapToInt(Line::lineNo).max().orElse(0) + 1;
        List<Line> next = new ArrayList<>(lines);
        next.add(new Line(nextNo, sku.trim(), quantity, unitPrice));
        return Result.ok(with(status, next, clock));
    }

    public Result<Order> removeLine(int lineNo, Clock clock) {
        if (status != Status.DRAFT) {
            return Result.err("Order.NotDraft", "Only a draft order can be changed.");
        }
        if (lines.stream().noneMatch(l -> l.lineNo() == lineNo)) {
            return Result.err("Order.Line.NotFound", "Line " + lineNo + " is not on this order.");
        }
        return Result.ok(with(status, lines.stream().filter(l -> l.lineNo() != lineNo).toList(), clock));
    }

    public Result<Outcome> submit(Clock clock) {
        if (status != Status.DRAFT) {
            return Result.err("Order.NotDraft", "Only a draft order can be submitted.");
        }
        if (lines.isEmpty()) {
            return Result.err("Order.Empty", "Add at least one line before submitting.");
        }
        Order submitted = with(Status.SUBMITTED, lines, clock);
        return Result.ok(new Outcome(submitted,
                List.of(new Event.Submitted(id, customer, submitted.total(), submitted.updatedAt()))));
    }

    public Result<Outcome> cancel(Clock clock) {
        if (status == Status.CANCELLED) {
            return Result.err("Order.AlreadyCancelled", "This order is already cancelled.");
        }
        Order cancelled = with(Status.CANCELLED, lines, clock);
        return Result.ok(new Outcome(cancelled, List.of(new Event.Cancelled(id, cancelled.updatedAt()))));
    }

    public BigDecimal total() {
        return lines.stream().map(Line::total).reduce(BigDecimal.ZERO, BigDecimal::add);
    }

    private Order with(Status newStatus, List<Line> newLines, Clock clock) {
        return new Order(id, customer, newStatus, newLines, version, createdAt, clock.instant());
    }
}
```

What to take from it:

- Rules that span the root and its children live on the root: no duplicate SKU, at most 50 lines, no change after submit. A `Line` cannot check any of those alone, which is the reason the root exists.
- The compact constructor copies `lines`, so a caller cannot mutate the list it passed in.
- Status changes are methods with names from the business (`submit`, `cancel`). There is no `setStatus`.
- The id type and the child type nest inside the root's file while they are small. Split them out when the file gets long.

## Saving an aggregate with children

```java
package pkg.features.orders;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.jdbi.v3.core.Handle;
import org.jdbi.v3.core.Jdbi;
import org.jdbi.v3.core.statement.PreparedBatch;
import pkg.features.orders.Order.Line;
import pkg.features.orders.Order.OrderId;
import pkg.features.orders.Order.Status;

/** Loads and saves a whole Order. There is no method that touches a line on its own. */
public final class OrderStore {
    private final Jdbi jdbi;

    public OrderStore(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public Optional<Order> find(OrderId id) {
        return jdbi.withHandle(h -> {
            List<Line> lines = h.createQuery("""
                            select line_no, sku, quantity, unit_price from order_lines
                            where order_id = :id order by line_no
                            """)
                    .bind("id", id.value())
                    .map((rs, ctx) -> new Line(
                            rs.getInt("line_no"), rs.getString("sku"), rs.getInt("quantity"), rs.getBigDecimal("unit_price")))
                    .list();
            return h.createQuery("select id, customer, status, version, created_at, updated_at from orders where id = :id")
                    .bind("id", id.value())
                    .map((rs, ctx) -> new Order(
                            new OrderId(rs.getObject("id", UUID.class)),
                            rs.getString("customer"),
                            Status.valueOf(rs.getString("status")),
                            lines,
                            rs.getInt("version"),
                            rs.getObject("created_at", OffsetDateTime.class).toInstant(),
                            rs.getObject("updated_at", OffsetDateTime.class).toInstant()))
                    .findOne();
        });
    }

    /**
     * One transaction for the root and its lines. Returns false when someone else saved the order
     * since this copy was loaded, in which case nothing was written.
     */
    public boolean save(Order order) {
        return jdbi.inTransaction(h -> {
            if (!saveRoot(h, order)) {
                return false;
            }
            h.createUpdate("delete from order_lines where order_id = :id")
                    .bind("id", order.id().value())
                    .execute();
            if (!order.lines().isEmpty()) {
                PreparedBatch batch = h.prepareBatch("""
                        insert into order_lines (order_id, line_no, sku, quantity, unit_price)
                        values (:orderId, :lineNo, :sku, :quantity, :unitPrice)
                        """);
                for (Line line : order.lines()) {
                    batch.bind("orderId", order.id().value())
                            .bind("lineNo", line.lineNo())
                            .bind("sku", line.sku())
                            .bind("quantity", line.quantity())
                            .bind("unitPrice", line.unitPrice())
                            .add();
                }
                batch.execute();
            }
            return true;
        });
    }

    private static boolean saveRoot(Handle h, Order order) {
        if (order.version() == 0) {
            return h.createUpdate("""
                            insert into orders (id, customer, status, version, created_at, updated_at)
                            values (:id, :customer, :status, 1, :createdAt, :updatedAt)
                            on conflict (id) do nothing
                            """)
                    .bind("id", order.id().value())
                    .bind("customer", order.customer())
                    .bind("status", order.status().name())
                    .bind("createdAt", order.createdAt())
                    .bind("updatedAt", order.updatedAt())
                    .execute() == 1;
        }
        return h.createUpdate("""
                        update orders set customer = :customer, status = :status, version = version + 1, updated_at = :updatedAt
                        where id = :id and version = :version
                        """)
                .bind("id", order.id().value())
                .bind("customer", order.customer())
                .bind("status", order.status().name())
                .bind("updatedAt", order.updatedAt())
                .bind("version", order.version())
                .execute() == 1;
    }
}
```

```sql
create table orders (
    id uuid primary key,
    customer text not null,
    status text not null,
    version int not null,
    created_at timestamptz not null,
    updated_at timestamptz not null
);
create table order_lines (
    order_id uuid not null references orders (id) on delete cascade,
    line_no int not null,
    sku text not null,
    quantity int not null,
    unit_price numeric(12, 2) not null,
    primary key (order_id, line_no)
);
```

Notes:

- The `version` column is the concurrency check. Two people open the same order, both save, and the second `update` matches zero rows. `save` returns `false` and the caller tells the user to reload. Add the column to any aggregate that two people can edit at once. A single-table aggregate edited by one admin can skip it, as `Item` does.
- After a successful `save`, load the order again before changing it further. The copy in memory still has the old version number.
- Children are deleted and inserted again on each save. For tens of rows that is simpler than diffing and fast enough. Reconsider when a parent has thousands of children, and at that point ask whether those children are really part of the aggregate.
- The child's key is `(order_id, line_no)`. A child does not need a global id.

## Domain events

Add them when a change must cause something outside the aggregate: send an email, write an audit row, update another aggregate, refresh a dashboard count. With no consumer, skip them. An event nobody handles is dead code that readers still have to understand.

Records cannot gather events on the side, so a method that raises events returns an `Outcome` holding the new state and the events, as `Order.submit` does. Publish after the save succeeds.

The dispatcher is small enough to own:

```java
package pkg;

import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.function.Consumer;

public final class DomainEvents {
    private final List<Consumer<Object>> handlers = new CopyOnWriteArrayList<>();

    public <E> void on(Class<E> type, Consumer<E> handler) {
        handlers.add(event -> {
            if (type.isInstance(event)) {
                handler.accept(type.cast(event));
            }
        });
    }

    public void publish(List<?> events) {
        for (Object event : events) {
            for (Consumer<Object> handler : handlers) {
                handler.accept(event);
            }
        }
    }
}
```

Handlers are registered once, in `App.java`, where the whole wiring is visible:

```java
DomainEvents events = new DomainEvents();
events.on(Order.Event.Submitted.class, e -> mailer.orderConfirmation(e.id(), e.customer(), e.total()));
events.on(Order.Event.class, audit::record);
```

The second line subscribes to the sealed interface and receives every order event.

Limits to be honest about:

- Handlers run in the request thread, after the transaction committed. A handler that throws does not undo the save. Catch and log inside handlers whose failure the user should not see.
- If the process dies between the save and the publish, the event is lost. When that is unacceptable, write the event to an outbox table inside the same transaction as the save and have a worker publish from the table. Build that when a real requirement asks for it.

## Application service

A route that loads, calls one method and saves does not need a layer between it and the store. `ItemRoutes` works that way.

Extract a service when a use case has steps beyond that, or when two routes need the same use case. One method per thing a user can do:

```java
package pkg.features.orders;

import java.time.Clock;
import java.util.List;
import java.util.Optional;
import pkg.DomainEvents;
import pkg.ErrorDetail;
import pkg.Result;
import pkg.features.orders.Order.OrderId;
import pkg.features.orders.Order.Outcome;

/** One method per thing a user can do to an order. Load, ask the aggregate, save, then publish. */
public final class OrderService {
    private final OrderStore store;
    private final DomainEvents events;
    private final Clock clock;

    public OrderService(OrderStore store, DomainEvents events, Clock clock) {
        this.store = store;
        this.events = events;
        this.clock = clock;
    }

    public Result<Order> submit(OrderId id) {
        Optional<Order> found = store.find(id);
        if (found.isEmpty()) {
            return Result.err("Order.NotFound", "That order no longer exists.");
        }
        return switch (found.get().submit(clock)) {
            case Result.Ok<Outcome>(Outcome outcome) -> {
                if (!store.save(outcome.order())) {
                    yield Result.err("Order.Stale", "Someone else changed this order. Reload and try again.");
                }
                events.publish(outcome.events());
                yield Result.ok(outcome.order());
            }
            case Result.Err<Outcome>(List<ErrorDetail> errors) -> Result.err(errors);
        };
    }
}
```

The service holds no rules. It sequences: load, ask the aggregate, save, publish. If an `if` about the business appears in a service or a route, it belongs on the aggregate.

## Value objects

Make one when a value has a rule or a behaviour that would otherwise be repeated: an amount with a currency, an email address, a date range. A record with a validating factory is the whole pattern:

```java
public record EmailAddress(String value) {
    public static Result<EmailAddress> of(String raw) {
        String trimmed = raw == null ? "" : raw.trim().toLowerCase();
        if (!trimmed.matches("[^@\\s]+@[^@\\s]+\\.[^@\\s]+")) {
            return Result.err("Email.Invalid", "Enter a valid email address.");
        }
        return Result.ok(new EmailAddress(trimmed));
    }
}
```

Do not wrap every `String`. A product name with a length limit is a field with a check in the factory.

## What to leave out

- Base classes such as `Entity<T>` or `AggregateRoot`. Records give you equality and immutability already.
- A command or query object per use case with a bus to dispatch it. The route is the dispatch.
- A generic `Repository<T, ID>` interface. Each store has the queries its aggregate needs and no others.
- An interface per store with one implementation. Extract one when a second implementation exists.
- A separate domain module or `domain/` layer. The aggregate lives in its feature package next to its store.

## Sizing the first feature

Ask during discovery, because the answers pick the shape:

| Answer | Build |
|--------|-------|
| Flat fields, one table | `Item` shape. Routes call the store. |
| Rows that belong to a parent | `Order` shape: children nested in the root, one store, `version` column. |
| A status with allowed moves | Named methods on the root, as `submit` and `cancel`. |
| Something must happen after a change | Events in an `Outcome`, `DomainEvents`, a service method. |
| Two users can edit the same record | `version` column and the stale check. |
