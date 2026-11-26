# Login page

Greenfield. hydra attach with `UI_AUTH=off` skips this. If they turn `UI_AUTH=on`, reuse the landing layout and a single env password, still no users table.

## What they see

`/login` is a centered card on `landing.css`. After POST, session cookie, redirect `/dashboard`.

## Files

```
src/main/java/pkg/features/auth/AuthRoutes.java
src/main/java/pkg/features/auth/UserStore.java
src/main/jte/layout/landing.jte
src/main/jte/auth/login.jte
src/main/resources/db/migration/V001__users.sql
src/main/resources/public/css/landing.css
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

Hash with `at.favre.lib.crypto.bcrypt.BCrypt`. Cost 12.

On boot, if `users` is empty, insert `DEV_ADMIN_USERNAME` / `DEV_ADMIN_PASSWORD`. Log that you seeded, never log the password.

## `AuthRoutes`

- `GET /login` renders `auth/login.jte`. If already in session, redirect `/dashboard`.
- `POST /login` reads `username` and `password`. Look up user. `BCrypt.verifyer().verify(password.toCharArray(), hash)`. On failure, re-render with an error message. On success, session attribute, rotate CSRF, redirect.
- `POST /logout` invalidates the session and redirects `/login`.

Use a normal HTML form POST for login. Datastar loading spinner on the button is fine (`data-indicator`). Do not SSE the login.

## landing.jte

No sidebar. `landing.css`. Same theme-mode inline script as the app shell. Logo optional.

Login card fields: username, password, submit. `data-indicator:_loading` on the button.

## Session cookie

HttpOnly, SameSite=Lax. See [javalin-app.md](javalin-app.md). This is the prototype RBAC stub the hydra design said would fit. Context 11 replaces it later; do not pretend this is SSO.
