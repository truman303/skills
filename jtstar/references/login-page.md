# Login page

> Placeholders: `MyApp` is the display name, `pkg` the Java package. See SKILL.md.

Greenfield sign-in: a users table, bcrypt hashes, a session cookie. When attaching to an existing app, see the sign-in section of [attach-existing-app.md](attach-existing-app.md) first.

## What the user sees

`/login` shows a centred card. A correct username and password sets the session cookie and redirects to `/dashboard`. A wrong one shows the form again with one message that does not say which of the two was wrong.

## Files

```
src/main/java/pkg/features/auth/AuthRoutes.java
src/main/java/pkg/features/auth/UserStore.java
src/main/java/pkg/features/auth/User.java
src/main/jte/layout/landing.jte
src/main/jte/auth/login.jte
src/main/resources/db/migration/V001__users.sql
```

## Schema

```sql
create table users (
    id uuid primary key,
    username text not null unique,
    password_hash text not null,
    created_at timestamptz not null
);
```

## `User` and `UserStore`

```java
package pkg.features.auth;

import java.time.Instant;
import java.util.UUID;

public record User(UUID id, String username, String passwordHash, Instant createdAt) {}
```

```java
package pkg.features.auth;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.Optional;
import java.util.UUID;
import org.jdbi.v3.core.Jdbi;

public final class UserStore {
    private final Jdbi jdbi;

    public UserStore(Jdbi jdbi) {
        this.jdbi = jdbi;
    }

    public long count() {
        return jdbi.withHandle(h -> h.createQuery("select count(*) from users")
                .mapTo(Long.class)
                .one());
    }

    public Optional<User> findByUsername(String username) {
        return jdbi.withHandle(h -> h.createQuery("""
                        select id, username, password_hash, created_at
                        from users
                        where username = :username
                        """)
                .bind("username", username)
                .map((rs, ctx) -> new User(
                        rs.getObject("id", UUID.class),
                        rs.getString("username"),
                        rs.getString("password_hash"),
                        rs.getObject("created_at", OffsetDateTime.class).toInstant()))
                .findOne());
    }

    public void insert(User user) {
        jdbi.useHandle(h -> h.createUpdate("""
                        insert into users (id, username, password_hash, created_at)
                        values (:id, :username, :passwordHash, :createdAt)
                        """)
                .bind("id", user.id())
                .bind("username", user.username())
                .bind("passwordHash", user.passwordHash())
                .bind("createdAt", user.createdAt())
                .execute());
    }

    public void seedAdminIfEmpty(String username, String passwordHash, Clock clock) {
        if (count() > 0) {
            return;
        }
        insert(new User(UUID.randomUUID(), username, passwordHash, clock.instant()));
    }
}
```

## `AuthRoutes`

```java
package pkg.features.auth;

import at.favre.lib.crypto.bcrypt.BCrypt;
import io.javalin.http.Context;
import io.javalin.router.JavalinDefaultRoutingApi;
import java.time.Clock;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;
import org.jdbi.v3.core.Jdbi;
import pkg.features.notifications.Notification.Kind;
import pkg.features.notifications.Notifier;
import pkg.web.Message;
import pkg.web.SessionAuth;

public final class AuthRoutes {
    private static final Logger LOG = LogManager.getLogger(AuthRoutes.class);

    private final UserStore store;

    public AuthRoutes(Jdbi jdbi, Clock clock, Notifier notifier) {
        this.store = new UserStore(jdbi);
        if (store.count() == 0) {
            String username = System.getenv("DEV_ADMIN_USERNAME");
            String password = System.getenv("DEV_ADMIN_PASSWORD");
            if (username == null || password == null) {
                throw new IllegalStateException("Set DEV_ADMIN_USERNAME and DEV_ADMIN_PASSWORD to create the first user.");
            }
            store.seedAdminIfEmpty(username, BCrypt.withDefaults().hashToString(12, password.toCharArray()), clock);
            LOG.info("created the first user ({})", username);
            notifier.send(username, Kind.INFO, "Welcome to MyApp",
                    "Things that happen while you are elsewhere are listed here until you dismiss them.");
        }
    }

    public void register(JavalinDefaultRoutingApi routes) {
        routes.get("/login", this::loginForm);
        routes.post("/login", this::login);
        routes.post("/logout", this::logout);
    }

    private void loginForm(Context ctx) {
        if (ctx.sessionAttribute(SessionAuth.USER) != null) {
            ctx.redirect("/dashboard");
            return;
        }
        ctx.render("auth/login.jte", Map.of("page", new LoginPage(List.of())));
    }

    private void login(Context ctx) {
        String username = value(ctx.formParam("username"));
        String password = ctx.formParam("password") == null ? "" : ctx.formParam("password");
        Optional<User> user = store.findByUsername(username);
        boolean ok = user
                .map(u -> BCrypt.verifyer().verify(password.toCharArray(), u.passwordHash()).verified)
                .orElse(false);
        if (!ok) {
            ctx.status(401);
            ctx.render("auth/login.jte", Map.of("page", new LoginPage(
                    List.of(new Message("error", "Invalid username or password.", List.of())))));
            return;
        }
        SessionAuth.establish(ctx, user.orElseThrow().username());
        ctx.redirect("/dashboard");
    }

    private void logout(Context ctx) {
        ctx.req().getSession().invalidate();
        ctx.redirect("/login");
    }

    private static String value(String raw) {
        return raw == null ? "" : raw.trim();
    }

    public record LoginPage(List<Message> messages) {}
}
```

Notes:

- The first user is created only when the table is empty. Log the username, never the password.
- The first user also gets a welcome notification, so the bell has something in it on the first run. See [notifications.md](notifications.md).
- `User` is a record because nothing changes a user yet. It is a row read at sign-in. When a feature such as changing a password arrives, make `User` an aggregate class as [domain-modeling.md](domain-modeling.md) describes.
- `SessionAuth.establish` changes the session id and creates the CSRF token. See [javalin-app.md](javalin-app.md).
- The log out button in the layout is a form with the hidden `csrf` field. `POST /logout` is not public, so `SessionAuth` checks it.
- Login is a plain form post. It does not use SSE.

## `layout/landing.jte`

No sidebar, no header. `landing.css` adds the background image and the translucent card.

```html
@import gg.jte.Content
@param String title
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
    <link rel="stylesheet" href="/css/tailwind-output.css">
    <link rel="stylesheet" href="/css/landing.css">
</head>
<body class="landing-page min-h-screen flex items-center justify-center p-4 m-0">
    <div class="landing-card max-w-md w-full p-8 rounded-xl shadow-2xl">
        ${content}
    </div>
</body>
</html>
```

`landing.css` points at `/images/key-visual.jpg` for the background. Ask the user for an image and save it as `src/main/resources/public/images/key-visual.jpg`. With no image the page falls back to the theme's background colour.

## `auth/login.jte`

```html
@import pkg.features.auth.AuthRoutes.LoginPage
@param LoginPage page

@template.layout.landing(
    title = "Log in",
    content = @`
        <div class="text-center mb-6">
            <h1 class="text-xl font-bold text-foreground leading-tight">MyApp</h1>
            <p class="text-sm text-muted-foreground mt-1">Sign in to continue</p>
        </div>
        @template.fragments.messages(messages = page.messages())
        <form method="post" action="/login" class="space-y-4">
            <div class="space-y-1">
                <label class="text-sm font-medium" for="username">Username</label>
                <input id="username" name="username" type="text" autocomplete="username" required autofocus class="input w-full">
            </div>
            <div class="space-y-1">
                <label class="text-sm font-medium" for="password">Password</label>
                <input id="password" name="password" type="password" autocomplete="current-password" required class="input w-full">
            </div>
            <button type="submit" class="btn-primary w-full">Log in</button>
        </form>
    `
)
```

The landing layout does not load Datastar, so the dismiss button on the message does nothing here. That is acceptable on a page that reloads on every attempt.

## Limits

This is single-factor sign-in for an internal app: no password reset, no lockout, no roles. Say so to the user. If they need more, that is a feature to design with them, not a default to guess.
