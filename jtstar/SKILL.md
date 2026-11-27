---
name: jtstar
description: Build a server-rendered Java web app with Javalin, JTE templates, Datastar (SSE HTML patching), Basecoat UI, and PostgreSQL via Jdbi, with a small DDD-style domain model (aggregates, typed ids, domain events when needed). Use when the user asks to create a jtstar app, a Javalin+JTE+Datastar app, a Java SSR CRUD app, or a web UI for an existing Java application. Offer this stack when they want a Java web app without a SPA, Spring, or Hibernate.
---

# JtStar app builder

A JtStar app is a Javalin process that renders JTE templates and uses Datastar for reactivity. Pages are rendered on the server. Where a page needs to change without reloading, the server sends HTML over SSE and Datastar morphs it in. The look comes from Basecoat and Tailwind.

Work through the phases with the user. Do not skip the checkpoints.

## Table of contents

- [Tech stack](#tech-stack)
- [Bundled resources](#bundled-resources)
- [Phase 1: Discovery](#phase-1-discovery)
- [Phase 2: Scaffold](#phase-2-scaffold)
- [Phase 3: First run](#phase-3-first-run)
- [Phase 4: First feature](#phase-4-first-feature)
- [Phase 5: Handoff](#phase-5-handoff)
- [Architecture principles](#architecture-principles)
- [What goes where](#what-goes-where)
- [Name substitution](#name-substitution)
- [References](#references)

## Tech stack

| Layer | Technology | Notes |
|-------|------------|-------|
| HTTP | Javalin 7, virtual threads on | `App.java` wires everything by hand. No container. |
| Templates | JTE 3 | Type-safe `.jte` files compiled to Java |
| Reactivity | Datastar v1.0.5 + `datastar-java-sdk-core` 1.0.1 | The SDK has no Javalin module. The skill supplies the adapter. |
| Components and CSS | Basecoat UI + Tailwind v4 | Copied from `assets/` |
| Persistence | Jdbi 3 + HikariCP + PostgreSQL | Hand-written SQL in each store, rows mapped by hand. No ORM. |
| Schema | Flyway | Runs at startup |
| Domain | Plain Java 21 | Aggregates and entities are classes. Ids, value objects and events are records. `Result<T>` for expected failures. |
| Auth | Session cookie + bcrypt | CSRF protection included |
| Notifications | A bell in the top bar, fed over SSE | One table, no extra dependency |
| Logging | Log4j2 | |

Java 21. Frontend libraries and fonts are bundled locally, so the app works with no internet access.

The browser library and the Java SDK are a matched pair. Use the bundled `assets/js/datastar.js` and the SDK version in [project-scaffolding.md](references/project-scaffolding.md). Do not swap either for "latest" without rerunning the browser checks in [crud-pages.md](references/crud-pages.md).

## Bundled resources

`${SKILL_DIR}` is this skill's directory.

| Folder | Contents | When |
|--------|----------|------|
| `assets/` | CSS (Basecoat, Tailwind entry, theme, landing), JS (Basecoat, Datastar, site) and the fonts the theme names | Copied into `src/main/resources/public/` in Phase 2 |
| `scripts/` | `start-dev-environment.sh` | Copied in Phase 2, greenfield only |
| `references/` | Implementation docs with complete code | Read as each step needs them. Not copied. |

The code in `references/` is complete and has been run. Copy it and rename. Do not reinvent the helpers from memory: several of them encode fixes for problems that only show up in a browser.

## Phase 1: Discovery

**Do not scaffold until this phase is done.** It takes two or three exchanges.

### 1A. New app or existing app?

Ask: *"Is this a new app from scratch, or a web UI for a Java application that already exists?"*

| Track | When | Database |
|-------|------|----------|
| **Greenfield** | Empty folder or a new Gradle build | The skill sets up Postgres in Docker |
| **Attach** | An existing Java process needs screens | The host's database. No second one. |

For attach, read [attach-existing-app.md](references/attach-existing-app.md) now. It has its own questions and replaces the greenfield scaffold steps.

### 1B. Name and package

Ask: *"What should the app be called, and what Java package should we use?"*

| Placeholder | Meaning | Example |
|-------------|---------|---------|
| `MyApp` | Display name in the title, sidebar and footer | `InventoryTracker` |
| `myapp` | Lowercase name for Docker and the database | `inventorytracker` |
| `pkg` | Java package | `com.example.inventory` |

Credentials are never hardcoded. They live in `.env`, which is gitignored.

### 1C. The first feature

Every greenfield app ships with login and a dashboard. It also needs one real feature to prove the stack end to end.

Ask: *"What is the first thing this app should manage? Give me its name and its fields, with a type for each."*

Then ask the questions that decide the shape of the domain code. Skip any the user has already answered.

| Question | Why it matters |
|----------|----------------|
| Does one of these have rows that belong to it, such as lines on an order? | Child entities inside the aggregate, saved together |
| Does it move through statuses, with rules about which moves are allowed? | Named methods on the aggregate, not a status dropdown |
| Must anything else happen when it changes: an email, an audit entry, another record updated? | Domain events and a service method |
| Can two people edit the same one at the same time? | A version column and a stale-save check |
| Which fields must be unique? | A database index and a check beside the store |

If every answer is no, the feature is a flat aggregate like `Item` in the references. That is common and fine. See [domain-modeling.md](references/domain-modeling.md) for each shape.

Also ask: *"What do people get wrong when they fill this in, and is there anything a field name does not make obvious?"* The answer goes into the Guidelines card beside the create and edit forms.

### 1D. Theme and layout

The default theme lives in `assets/css/theme.css`. Offer, in one message:

- a custom colour theme from [tweakcn](https://tweakcn.com/editor/theme), pasted in before scaffolding
- a logo for the sidebar
- a background image for the login page

Any of these can wait. See [theme-customization.md](references/theme-customization.md).

Ask: *"Sidebar, top navigation, or a minimal header?"*

| Option | Use when |
|--------|----------|
| **Sidebar** (default) | Several sections |
| **Top nav** | A few sections |
| **Minimal header** | One purpose, pages link to each other |

### 1E. Confirm the plan

> *"Here's what I'll set up for **InventoryTracker** (`com.example.inventory`):*
> 1. *Javalin 7, JTE, Datastar and Basecoat on Java 21*
> 2. *PostgreSQL in Docker, credentials in `.env`*
> 3. *Session login with a first admin user from `.env`*
> 4. *Sidebar navigation, and a top bar with a dark-mode switch and a notification bell*
> 5. *A dashboard with one summary card*
> 6. *Products (name, price, active): list with live search and paging, create, edit, details, delete. Create and edit carry a Guidelines card that explains the rules.*
> 7. *A README with the commands to start the app and to rebuild the styles*
>
> *Sound good?"*

Wait for confirmation.

---

## Phase 2: Scaffold

Work in order. Substitute `MyApp`, `myapp` and `pkg` everywhere.

1. Gradle Java 21 project and packages. [project-scaffolding.md](references/project-scaffolding.md)
2. `.env`, Docker Postgres, and `scripts/start-dev-environment.sh`. [docker-setup.md](references/docker-setup.md)
3. Copy `assets/` into `src/main/resources/public/`, fonts included. Build `tailwind-output.css` with the Tailwind CLI.
4. `Result` and `ErrorDetail`, from [architecture-patterns.md](references/architecture-patterns.md). `AggregateRoot`, from [domain-modeling.md](references/domain-modeling.md).
5. The `pkg.web` kit: `JavalinResponseAdapter`, `Sse`, `Signals`, `TableState`, `Message`, `Templates`. [datastar-sse.md](references/datastar-sse.md)
6. `App.java`, `SessionAuth`, `ExceptionMapping`, `error.jte`. [javalin-app.md](references/javalin-app.md)
7. The layout for the chosen navigation, plus `fragments/messages.jte` and `fragments/toast.jte`. [jte-templates.md](references/jte-templates.md) and [crud-pages.md](references/crud-pages.md)
8. The notification bell: its feature package, its three templates and its migration. [notifications.md](references/notifications.md)
9. Login and dashboard. [login-page.md](references/login-page.md) and [dashboard-page.md](references/dashboard-page.md)
10. Run `./gradlew build`. JTE templates compile during the build, so a template error shows up here.
11. `README.md` in the project root: what the app is, the commands to start it, and the commands to rebuild the styles. [readme-pattern.md](references/readme-pattern.md)

---

## Phase 3: First run

**Checkpoint. Do not build the first feature until the user has seen the app.**

> *"The base app is ready.*
> 1. `./scripts/start-dev-environment.sh`
> 2. `./gradlew run`
> 3. *Open http://localhost:8080*
> 4. *Sign in with `DEV_ADMIN_USERNAME` and `DEV_ADMIN_PASSWORD` from `.env`*
> 5. *The bell in the top bar should show 1. Open it and read the welcome notification.*
>
> *The same steps are in `README.md`. Tell me when you're in."*

Wait for confirmation.

---

## Phase 4: First feature

```
src/main/java/pkg/features/items/
  ItemId.java        # typed id
  Item.java          # aggregate root, a class: factory, methods, rules
  ItemForm.java      # posted strings, parsed to types
  ItemStore.java     # Jdbi
  ItemPages.java     # page records the templates print
  ItemRoutes.java
src/main/jte/items/
  index.jte          # signals, toolbar, delete dialog
  table.jte          # the fragment SSE patches
  fields.jte         # inputs shared by create and edit
  guidelines.jte     # the rules in the user's words, beside both forms
  create.jte
  edit.jte
  details.jte
src/main/resources/db/migration/
  V003__items.sql
```

Build it in this order:

1. The domain: id, aggregate, form record, store, migration. [domain-modeling.md](references/domain-modeling.md)
2. The pages and routes. [crud-pages.md](references/crud-pages.md)
3. Wiring: construct and register in `App.java`, add a nav link, add a dashboard card. [crud-feature-reference.md](references/crud-feature-reference.md)

The index page must behave like this:

- Search, paging and page size update the table without reloading the page.
- Delete asks for confirmation, updates the table and shows a toast.
- Create and edit are ordinary forms that redirect with a flash message.
- Create and edit show a Guidelines card beside the form. It lists every rule a save can fail on, in the user's words. Draft it from the aggregate and from what the user said in discovery, then ask the user to read it.

The full check is the list at the end of [crud-pages.md](references/crud-pages.md). Run it in a browser yourself if you can drive one. If you cannot, give the user the list and ask them to run it. A build that compiles proves nothing about whether a click reaches the server.

---

## Phase 5: Handoff

Tell the user what they have: login, dashboard, the notification bell, one complete feature. Then how to add the next one: copy the feature package and template folder, rename, write the migration, rewrite the Guidelines card for the new rules, register in `App.java`, add the nav link and the card.

Nothing sends notifications yet apart from the welcome. Ask which events in their app a user would want to hear about later, and wire `notifier.send(...)` there.

Bring `README.md` up to date before you point the user at it. Its first paragraph names the first feature, and anything that changed during the first run, such as a port, is in it. [readme-pattern.md](references/readme-pattern.md)

The stylesheet needs a rebuild after a theme edit, and whenever a template uses a Tailwind class for the first time:

```bash
./tailwindcss -i src/main/resources/public/css/site.css -o src/main/resources/public/css/tailwind-output.css
```

Then restart the app, because it serves the copy of the stylesheet that `./gradlew run` makes at start. Add `--watch` to rebuild on every save. The README's Styles section says the same, so the user does not have to remember it.

---

## Architecture principles

1. **The server renders.** A GET returns a full page. Links navigate between pages and the browser owns history.
2. **Datastar updates a page in place.** Table search, paging, page size and row actions fetch a fragment over SSE and morph it in. They never reload the page. A pager built from links is a bug.
3. **The server holds the state.** Signals carry what the user is typing and the few values the server needs back. Rows, counts and messages are HTML.
4. **One fragment, two uses.** The template that renders a table inside the page is the same one an SSE handler patches, so the first render and every update match.
5. **Aggregates own the rules.** An aggregate root is a class with private state, a private constructor and no setters. Its factory and methods return `Result`, so anything that exists is valid. Records are for ids, value objects, events, forms and page data. Routes and services sequence work and hold no rules.
6. **Typed at the edge.** A form record turns posted strings into types. The aggregate never parses text.
7. **One store per aggregate.** It loads and saves the whole aggregate in one transaction. The SQL is written out in the store.
8. **Events only with a consumer.** Add domain events when a change must cause something elsewhere. Not before.
9. **Expected failures are values.** Validation, not found and rule violations are `Result.Err`. Exceptions are for what nobody planned.
10. **Features, not layers.** `features/items/` holds everything about items.
11. **No user text inside a Datastar expression.** Pass it through a `data-*` attribute or a JSON-encoded signal.
12. **Forms explain themselves.** Every create and edit page has a Guidelines card. A user should not have to fail a save to learn a rule.

## What goes where

| Interaction | Mechanism |
|-------------|-----------|
| Moving between pages | `<a href>` and a full page GET |
| Create and edit forms | Form POST, redirect, flash message |
| Table search, paging, page size | Signals and `@get` of the table fragment |
| Row actions such as delete | `@post`, then patch the table and append a toast |
| Progress of a running job | A live SSE view opened with `data-init` |
| News for a user who was elsewhere | `notifier.send(...)`, shown behind the bell |
| Dialogs and toggles | A signal or a DOM call in `data-on:click` |
| Rates and time-series charts | Prometheus and Grafana. Link to them. |

## Name substitution

| Placeholder | Meaning |
|-------------|---------|
| `MyApp` | Display name (`InventoryTracker`) |
| `myapp` | Docker service and database name |
| `pkg` | Java package (`com.example.inventory`) |
| `Item`, `items` | The first feature's type and URL segment |

## References

- [project-scaffolding.md](references/project-scaffolding.md): Gradle, versions, static files, Tailwind
- [docker-setup.md](references/docker-setup.md): Postgres in Docker, `.env`
- [readme-pattern.md](references/readme-pattern.md): the app's own README, with the start and style rebuild commands
- [architecture-patterns.md](references/architecture-patterns.md): package layout, `Result`, who calls whom
- [domain-modeling.md](references/domain-modeling.md): aggregates and entities as classes, value objects and typed ids as records, stores, domain events
- [javalin-app.md](references/javalin-app.md): `App.java`, sessions, CSRF, exception handling
- [datastar-sse.md](references/datastar-sse.md): the SSE kit, signals, table state, live views
- [jte-templates.md](references/jte-templates.md): layout, fragments, JTE syntax traps
- [crud-pages.md](references/crud-pages.md): every template and route for one feature, including the Guidelines card
- [notifications.md](references/notifications.md): the bell in the top bar, its stream, and how features send to it
- [crud-feature-reference.md](references/crud-feature-reference.md): file checklist and route table
- [ui-component-patterns.md](references/ui-component-patterns.md): Basecoat classes, Datastar attributes, dialogs, messages
- [login-page.md](references/login-page.md): users table, bcrypt, login and logout
- [dashboard-page.md](references/dashboard-page.md): summary cards
- [theme-customization.md](references/theme-customization.md): tweakcn themes
- [observability.md](references/observability.md): what belongs in Grafana
- [attach-existing-app.md](references/attach-existing-app.md): adding a UI to an existing Java app
