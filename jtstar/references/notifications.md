# Notifications

> Placeholders: `MyApp` is the display name, `pkg` the Java package. See SKILL.md.

The bell in the top bar. It shows how many notifications the signed-in user has not read, and opens a panel that lists them. Every greenfield app gets it during scaffolding.

## What it is for

A notification tells a user about something that happened while they were not looking: a background job finished, someone else changed a record they own, an import failed overnight. It waits behind the bell until they read it.

| The user | Use |
|----------|-----|
| Just did something and stayed on the page | Toast |
| Just did something and was redirected | Flash message |
| Must fix something before going on | Message in `#messages` |
| Was elsewhere when it happened | Notification |

Do not send a notification for the user's own click. They watched it happen.

## How it works

1. The layout includes `notifications/bell.jte`. It renders an empty badge and a panel that says it is loading.
2. `data-init` on the bell opens `GET /notifications/stream`, a live SSE view.
3. The stream sends the badge and the panel at once, then checks every five seconds and sends them again when they changed.
4. Mark read, Dismiss and Mark all read are `@post` actions. Each answers with the badge and the panel, so the tab that clicked updates immediately. Other tabs catch up on their next check.
5. Any feature puts a notification in a user's bell with `notifier.send(...)`.

The stream polls the table. It does not listen to an in-process channel, so it keeps working when two instances of the app run behind a load balancer, and it needs no shared state. The cost is two indexed queries per open tab every five seconds and a delay of up to five seconds.

Datastar closes the stream while a tab is hidden and opens it again when the tab returns, so background tabs cost nothing.

## Files

```
src/main/java/pkg/features/notifications/
  NotificationId.java       typed id
  Notification.java         aggregate root
  NotificationStore.java
  Notifier.java             what other features call
  NotificationPages.java    page records for the panel
  NotificationRoutes.java
src/main/jte/notifications/
  bell.jte                  the button and popover, included by the layout
  count.jte                 fragment: the unread badge
  panel.jte                 fragment: the list
src/main/resources/db/migration/
  V002__notifications.sql
```

## Schema

```sql
create table notifications (
    id uuid primary key,
    recipient text not null,
    kind text not null,
    title text not null,
    message text not null,
    link_url text not null,
    link_text text not null,
    created_at timestamptz not null,
    read_at timestamptz,
    dismissed_at timestamptz
);
create index notifications_recipient_idx on notifications (recipient, created_at desc) where dismissed_at is null;
```

`recipient` is the username that `SessionAuth.userName(ctx)` returns.

## The aggregate

`NotificationId` is `ItemId` from [domain-modeling.md](domain-modeling.md) with the name changed.

```java
package pkg.features.notifications;

import java.time.Clock;
import java.time.Instant;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import pkg.AggregateRoot;
import pkg.ErrorDetail;
import pkg.Result;

/** Aggregate root. One message for one user, kept behind the bell until they dismiss it. */
public final class Notification extends AggregateRoot<NotificationId> {
    public static final int TITLE_MAX = 200;
    public static final int MESSAGE_MAX = 2000;

    public enum Kind { INFO, SUCCESS, WARNING, ERROR }

    private final String recipient;
    private final Kind kind;
    private final String title;
    private final String message;
    private final String linkUrl;
    private final String linkText;
    private final Instant createdAt;
    private Instant readAt;
    private Instant dismissedAt;

    private Notification(NotificationId id, String recipient, Kind kind, String title, String message,
            String linkUrl, String linkText, Instant createdAt, Instant readAt, Instant dismissedAt) {
        super(id);
        this.recipient = recipient;
        this.kind = kind;
        this.title = title;
        this.message = message;
        this.linkUrl = linkUrl;
        this.linkText = linkText;
        this.createdAt = createdAt;
        this.readAt = readAt;
        this.dismissedAt = dismissedAt;
    }

    /** Pass an empty linkUrl when the notification has no page to send the user to. */
    public static Result<Notification> create(String recipient, Kind kind, String title, String message,
            String linkUrl, String linkText, Clock clock) {
        List<ErrorDetail> errors = new ArrayList<>();
        if (recipient == null || recipient.isBlank()) {
            errors.add(new ErrorDetail("Notification.Recipient.Empty", "A notification needs a recipient."));
        }
        if (kind == null) {
            errors.add(new ErrorDetail("Notification.Kind.Empty", "A notification needs a kind."));
        }
        if (title == null || title.isBlank() || title.trim().length() > TITLE_MAX) {
            errors.add(new ErrorDetail("Notification.Title.Invalid", "The title must have 1 to " + TITLE_MAX + " characters."));
        }
        if (message == null || message.isBlank() || message.trim().length() > MESSAGE_MAX) {
            errors.add(new ErrorDetail("Notification.Message.Invalid", "The message must have 1 to " + MESSAGE_MAX + " characters."));
        }
        String url = linkUrl == null ? "" : linkUrl.trim();
        if (!url.isEmpty() && (!url.startsWith("/") || url.startsWith("//"))) {
            errors.add(new ErrorDetail("Notification.Link.NotLocal", "A notification can only link to a page in this app."));
        }
        if (!errors.isEmpty()) {
            return Result.err(errors);
        }
        String text = url.isEmpty() ? "" : (linkText == null || linkText.isBlank() ? "Open" : linkText.trim());
        return Result.ok(new Notification(NotificationId.create(), recipient.trim(), kind, title.trim(), message.trim(),
                url, text, clock.instant(), null, null));
    }

    /** For NotificationStore only. */
    static Notification rehydrate(NotificationId id, String recipient, Kind kind, String title, String message,
            String linkUrl, String linkText, Instant createdAt, Instant readAt, Instant dismissedAt) {
        return new Notification(id, recipient, kind, title, message, linkUrl, linkText, createdAt, readAt, dismissedAt);
    }

    /** Reading it twice keeps the first time. */
    public void markRead(Clock clock) {
        if (readAt == null) {
            readAt = clock.instant();
        }
    }

    public void dismiss(Clock clock) {
        if (dismissedAt == null) {
            dismissedAt = clock.instant();
        }
    }

    public String recipient() { return recipient; }

    public Kind kind() { return kind; }

    public String title() { return title; }

    public String message() { return message; }

    public String linkUrl() { return linkUrl; }

    public String linkText() { return linkText; }

    public Instant createdAt() { return createdAt; }

    public boolean isRead() { return readAt != null; }

    public Optional<Instant> readAt() { return Optional.ofNullable(readAt); }

    public Optional<Instant> dismissedAt() { return Optional.ofNullable(dismissedAt); }
}
```

The link rule matters. The panel prints `linkUrl` into an `href`. A link that must start with one `/` cannot point at another site or carry a `javascript:` URL.

`markRead` and `dismiss` cannot fail, so they return nothing.

## The store

```java
package pkg.features.notifications;

import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import org.jdbi.v3.core.Jdbi;
import pkg.features.notifications.Notification.Kind;

public final class NotificationStore {
    private static final String COLUMNS =
            "id, recipient, kind, title, message, link_url, link_text, created_at, read_at, dismissed_at";
    private final Jdbi jdbi;

    public NotificationStore(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public void insert(Notification notification) {
        jdbi.useHandle(h -> h.createUpdate("""
                        insert into notifications (id, recipient, kind, title, message, link_url, link_text, created_at)
                        values (:id, :recipient, :kind, :title, :message, :linkUrl, :linkText, :createdAt)
                        """)
                .bind("id", notification.id().value())
                .bind("recipient", notification.recipient())
                .bind("kind", notification.kind().name().toLowerCase())
                .bind("title", notification.title())
                .bind("message", notification.message())
                .bind("linkUrl", notification.linkUrl())
                .bind("linkText", notification.linkText())
                .bind("createdAt", notification.createdAt())
                .execute());
    }

    /** Only the two fields that can change after a notification is created. */
    public void update(Notification notification) {
        jdbi.useHandle(h -> h.createUpdate("""
                        update notifications set read_at = :readAt, dismissed_at = :dismissedAt where id = :id
                        """)
                .bind("id", notification.id().value())
                .bindByType("readAt", notification.readAt().orElse(null), Instant.class)
                .bindByType("dismissedAt", notification.dismissedAt().orElse(null), Instant.class)
                .execute());
    }

    /** Scoped to the recipient, so nobody can read or dismiss a notification that is not theirs. */
    public Optional<Notification> find(NotificationId id, String recipient) {
        return jdbi.withHandle(h -> h.createQuery(
                        "select " + COLUMNS + " from notifications where id = :id and recipient = :recipient")
                .bind("id", id.value())
                .bind("recipient", recipient)
                .map((rs, ctx) -> map(rs))
                .findOne());
    }

    public List<Notification> latest(String recipient, int limit) {
        return jdbi.withHandle(h -> h.createQuery(
                        "select " + COLUMNS + " from notifications where recipient = :recipient and dismissed_at is null"
                                + " order by created_at desc, id limit :limit")
                .bind("recipient", recipient)
                .bind("limit", limit)
                .map((rs, ctx) -> map(rs))
                .list());
    }

    public int unreadCount(String recipient) {
        return jdbi.withHandle(h -> h.createQuery("""
                        select count(*) from notifications
                        where recipient = :recipient and dismissed_at is null and read_at is null
                        """)
                .bind("recipient", recipient)
                .mapTo(Integer.class)
                .one());
    }

    /** One statement for the whole set. There is no rule to check per notification, so none is loaded. */
    public void markAllRead(String recipient, Instant at) {
        jdbi.useHandle(h -> h.createUpdate("""
                        update notifications set read_at = :at
                        where recipient = :recipient and dismissed_at is null and read_at is null
                        """)
                .bind("recipient", recipient)
                .bind("at", at)
                .execute());
    }

    private static Notification map(ResultSet rs) throws SQLException {
        return Notification.rehydrate(
                new NotificationId(rs.getObject("id", UUID.class)),
                rs.getString("recipient"),
                Kind.valueOf(rs.getString("kind").toUpperCase()),
                rs.getString("title"),
                rs.getString("message"),
                rs.getString("link_url"),
                rs.getString("link_text"),
                instant(rs, "created_at"),
                instant(rs, "read_at"),
                instant(rs, "dismissed_at"));
    }

    private static Instant instant(ResultSet rs, String column) throws SQLException {
        OffsetDateTime value = rs.getObject(column, OffsetDateTime.class);
        return value == null ? null : value.toInstant();
    }
}
```

`bindByType` tells Jdbi the type of a value that may be `null`. A plain `bind` cannot tell what a `null` was meant to be.

Dismissed rows stay in the table. When it grows, delete old ones on a schedule: `delete from notifications where dismissed_at < now() - interval '90 days'`.

## `Notifier`

What every other feature calls. It is the only public way to create a notification.

```java
package pkg.features.notifications;

import java.time.Clock;
import java.util.List;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import pkg.ErrorDetail;
import pkg.Result;
import pkg.features.notifications.Notification.Kind;

/** Puts a notification in one user's bell. Never throws: a notification must not fail the work that caused it. */
public final class Notifier {
    private static final Logger LOG = LogManager.getLogger(Notifier.class);

    private final NotificationStore store;
    private final Clock clock;

    public Notifier(NotificationStore store, Clock clock) {
        this.store = store;
        this.clock = clock;
    }

    public void send(String recipient, Kind kind, String title, String message) {
        send(recipient, kind, title, message, "", "");
    }

    public void send(String recipient, Kind kind, String title, String message, String linkUrl, String linkText) {
        try {
            switch (Notification.create(recipient, kind, title, message, linkUrl, linkText, clock)) {
                case Result.Ok<Notification>(Notification notification) -> store.insert(notification);
                case Result.Err<Notification>(List<ErrorDetail> errors) ->
                        LOG.error("notification '{}' for {} was not sent: {}", title, recipient, errors);
            }
        } catch (RuntimeException e) {
            LOG.error("notification '{}' for {} was not sent", title, recipient, e);
        }
    }
}
```

Sending one:

```java
notifier.send(job.startedBy(), Kind.SUCCESS, "Import finished",
        job.rowCount() + " rows imported from " + job.fileName() + ".",
        "/imports/" + job.id(), "View import");
```

From a domain event, register the handler in `App.java`:

```java
events.on(Order.Event.Submitted.class, e -> notifier.send(
        "warehouse", Kind.INFO, "New order", "An order for " + e.customer() + " is ready to pick.",
        "/orders/" + e.id(), "Open order"));
```

A bad call from code, such as a blank title, is a bug and not something a user can fix. `Notifier` logs it and carries on. The save that raised the event has already happened and must stand.

To notify several people, call `send` once for each.

## Page records

```java
package pkg.features.notifications;

import java.time.Duration;
import java.time.Instant;
import java.util.List;

public final class NotificationPages {
    /** How many the panel lists. The badge counts every unread one, shown or not. */
    public static final int SHOWN = 20;

    private NotificationPages() {}

    public record Row(String id, String kind, String title, String message, boolean read, String when,
            String linkUrl, String linkText) {

        static Row of(Notification notification, Instant now) {
            return new Row(
                    notification.id().toString(),
                    notification.kind().name().toLowerCase(),
                    notification.title(),
                    notification.message(),
                    notification.isRead(),
                    ago(notification.createdAt(), now),
                    notification.linkUrl(),
                    notification.linkText());
        }

        public boolean hasLink() {
            return !linkUrl.isEmpty();
        }
    }

    public record Panel(boolean loading, int unread, List<Row> rows) {
        /** What the layout renders before the stream has answered. */
        public static Panel placeholder() {
            return new Panel(true, 0, List.of());
        }
    }

    static String ago(Instant then, Instant now) {
        long minutes = Math.max(0, Duration.between(then, now).toMinutes());
        if (minutes < 1) {
            return "just now";
        }
        if (minutes < 60) {
            return minutes + " min ago";
        }
        if (minutes < 60 * 24) {
            return minutes / 60 + " h ago";
        }
        return minutes / (60 * 24) + " d ago";
    }
}
```

## Routes

```java
package pkg.features.notifications;

import io.javalin.http.Context;
import io.javalin.router.JavalinDefaultRoutingApi;
import java.time.Clock;
import java.time.Duration;
import java.time.Instant;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import pkg.features.notifications.NotificationPages.Panel;
import pkg.features.notifications.NotificationPages.Row;
import pkg.web.SessionAuth;
import pkg.web.Sse;
import pkg.web.Templates;

public final class NotificationRoutes {
    private static final Duration POLL = Duration.ofSeconds(5);

    private final NotificationStore store;
    private final Clock clock;
    private final Templates templates;

    public NotificationRoutes(NotificationStore store, Clock clock, Templates templates) {
        this.store = store;
        this.clock = clock;
        this.templates = templates;
    }

    public void register(JavalinDefaultRoutingApi routes) {
        routes.get("/notifications/stream", this::stream);
        routes.post("/notifications/read-all", this::readAll);
        routes.post("/notifications/{id}/read", this::read);
        routes.post("/notifications/{id}/dismiss", this::dismiss);
    }

    /** Stays open while the page is visible. Sends the badge and panel now, then again whenever they change. */
    private void stream(Context ctx) throws InterruptedException {
        String user = SessionAuth.userName(ctx);
        Sse.open(ctx, templates).live(POLL, () -> render(user));
    }

    private void read(Context ctx) {
        String user = SessionAuth.userName(ctx);
        find(ctx, user).ifPresent(notification -> {
            notification.markRead(clock);
            store.update(notification);
        });
        Sse.open(ctx, templates).patchHtml(render(user));
    }

    private void dismiss(Context ctx) {
        String user = SessionAuth.userName(ctx);
        find(ctx, user).ifPresent(notification -> {
            notification.dismiss(clock);
            store.update(notification);
        });
        Sse.open(ctx, templates).patchHtml(render(user));
    }

    private void readAll(Context ctx) {
        String user = SessionAuth.userName(ctx);
        store.markAllRead(user, clock.instant());
        Sse.open(ctx, templates).patchHtml(render(user));
    }

    private Optional<Notification> find(Context ctx, String user) {
        return NotificationId.parse(ctx.pathParam("id")).flatMap(id -> store.find(id, user));
    }

    /** The badge and the panel. Two top-level elements, each matched to the page by its id. */
    private String render(String user) {
        Instant now = clock.instant();
        List<Row> rows = store.latest(user, NotificationPages.SHOWN).stream()
                .map(notification -> Row.of(notification, now))
                .toList();
        Panel panel = new Panel(false, store.unreadCount(user), rows);
        return templates.render("notifications/count.jte", Map.of("unread", panel.unread()))
                + templates.render("notifications/panel.jte", Map.of("panel", panel));
    }
}
```

Points that matter:

- `find` passes the signed-in user to the store. A notification id that belongs to someone else finds nothing, and the action does nothing.
- An id that no longer exists is not an error. The panel is patched and shows what is there.
- The POST routes need no CSRF field. They are Datastar actions, which `SessionAuth` checks by header and origin.

## `notifications/bell.jte`

The layout includes this in the top bar. It takes no parameters, so no page record has to carry notification data.

```html
@import pkg.features.notifications.NotificationPages.Panel

<div class="popover" data-init="@get('/notifications/stream', {filterSignals: {include: /^$/}})"
     data-on:keydown__window="evt.key === 'Escape' && document.dispatchEvent(new CustomEvent('basecoat:popover', {detail: {}}))">
    <button type="button" class="btn-icon-outline relative" aria-label="Notifications"
            aria-expanded="false" aria-controls="notifications-popover">
        <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M10.268 21a2 2 0 0 0 3.464 0"/><path d="M3.262 15.326A1 1 0 0 0 4 17h16a1 1 0 0 0 .74-1.673C19.41 13.956 18 12.499 18 8A6 6 0 0 0 6 8c0 4.499-1.411 5.956-2.738 7.326"/></svg>
        @template.notifications.count(unread = 0)
    </button>
    <div id="notifications-popover" data-popover aria-hidden="true" data-align="end" class="p-0">
        @template.notifications.panel(panel = Panel.placeholder())
    </div>
</div>
```

Basecoat's `popover` opens the panel, closes it on a click outside, and needs no signal. Its script looks for a `<button>` and a `[data-popover]` as direct children of `.popover`, so keep that structure.

`filterSignals` keeps the page's signals out of this request. A Datastar `@get` puts every signal in the query string, and the bell sits on every page, so without the filter the list page's search text would travel in the stream's address and land in the access log. The pattern `/^$/` matches no signal name, so nothing is sent. The stream needs only the session.

Basecoat closes a popover on Escape only while the focus is inside it. Mark read and Dismiss remove the button that was just clicked, which leaves the focus on the page body, and Escape then does nothing. The `data-on:keydown__window` line covers that case. It sends the event Basecoat uses to close its popovers, so Escape works wherever the focus is.

## `notifications/count.jte`

```html
@param int unread

<span id="notifications-count" class="absolute -top-1.5 -right-1.5">
    @if(unread > 0)
        <span class="badge-destructive px-1.5" aria-hidden="true">${unread > 99 ? "99+" : String.valueOf(unread)}</span>
        <span class="sr-only">${unread} unread</span>
    @endif
</span>
```

## `notifications/panel.jte`

```html
@import pkg.features.notifications.NotificationPages.Panel
@import pkg.features.notifications.NotificationPages.Row
@param Panel panel

<div id="notifications-panel" class="w-96 max-w-[90vw]">
    @if(panel.loading())
        <p class="p-4 text-sm text-muted-foreground">Loading notifications.</p>
    @else
        <header class="flex items-center justify-between gap-4 border-b border-border px-4 py-3">
            <div>
                <h3 class="font-semibold leading-tight">Notifications</h3>
                <p class="text-xs text-muted-foreground mt-1">${panel.unread()} unread</p>
            </div>
            <button type="button" class="btn-sm-outline" disabled="${panel.unread() == 0}"
                    data-on:click="@post('/notifications/read-all')">Mark all read</button>
        </header>
        @if(panel.rows().isEmpty())
            <p class="p-4 text-sm text-muted-foreground">No notifications.</p>
        @else
            <ul class="max-h-96 overflow-y-auto divide-y divide-border">
                @for(Row row : panel.rows())
                    <li id="notification-${row.id()}" class="flex items-start gap-3 p-4">
                        <span class="mt-1.5 inline-block size-2 shrink-0 rounded-full bg-primary data-[kind=success]:bg-green-500 data-[kind=warning]:bg-orange-400 data-[kind=error]:bg-destructive"
                              data-kind="${row.kind()}" aria-hidden="true"></span>
                        <div class="min-w-0 flex-1">
                            <div class="flex items-baseline justify-between gap-3">
                                <p class="text-sm ${row.read() ? "text-muted-foreground" : "font-semibold text-foreground"}">${row.title()}</p>
                                <span class="shrink-0 text-xs text-muted-foreground">${row.when()}</span>
                            </div>
                            <p class="text-sm text-muted-foreground mt-1 break-words">${row.message()}</p>
                            <div class="mt-2 flex flex-wrap items-center gap-2">
                                @if(row.hasLink())
                                    <a href="${row.linkUrl()}" class="btn-sm-secondary">${row.linkText()}</a>
                                @endif
                                @if(!row.read())
                                    <button type="button" class="btn-sm-ghost" id="notification-read-${row.id()}"
                                            data-on:click="@post('/notifications/${row.id()}/read')">Mark read</button>
                                @endif
                                <button type="button" class="btn-sm-ghost" id="notification-dismiss-${row.id()}"
                                        data-on:click="@post('/notifications/${row.id()}/dismiss')">Dismiss</button>
                            </div>
                        </div>
                    </li>
                @endfor
            </ul>
        @endif
    @endif
</div>
```

Points that matter:

- The row id goes inside the `@post` expression because the server made it. The title and message are user-facing text and are only ever printed as text.
- The dot's colour comes from `data-kind` and Tailwind's `data-[kind=...]` variants. Every class name is written out in the template, where Tailwind's scan finds it. A class name built in Java would be missing from the stylesheet.
- An unread row has a bold title and a Mark read button. A read row has neither.
- Each row and each of its two buttons has an id built from the notification id. Datastar morphs the old panel into the new one and pairs elements by id first. Without the ids it pairs them by position: the Mark read button you just clicked becomes that row's Dismiss button and keeps the keyboard focus, so pressing Enter twice marks a notification read and then dismisses it.

## Wiring

In `App.java`:

```java
NotificationStore notificationStore = new NotificationStore(jdbi);
Notifier notifier = new Notifier(notificationStore, clock);
NotificationRoutes notifications = new NotificationRoutes(notificationStore, clock, templates);
// inside Javalin.create
notifications.register(config.routes);
```

Pass `notifier` to whatever needs to send. `AuthRoutes` takes it and sends a welcome notification to the first user, so the bell has something in it on the first run.

## Check it in the browser

1. Sign in on a fresh database. The bell shows 1.
2. Click the bell. The panel lists the welcome notification with a bold title.
3. Click Mark read. The badge goes, the title is no longer bold, and the panel stays open.
4. Insert a row for your user by hand, or trigger whatever sends one. Within five seconds the badge shows 1 without a reload.
5. Click Dismiss. The row leaves the panel.
6. Press Escape straight after step 5, while the focus is on nothing. The panel closes. Open it again and click elsewhere on the page. It closes again.
7. Open a second tab, mark something read there, and return to the first. It agrees within five seconds.

## Limits

One recipient per notification, in-app only. No email, no browser push, no per-user settings. Each of those is a feature to design with the user.
