# CRUD feature reference

> Placeholders: `pkg` is the Java package, `Item` / `items` the feature. See SKILL.md.

The checklist for adding one feature. The code is in [domain-modeling.md](domain-modeling.md) and [crud-pages.md](crud-pages.md).

## Files

```
src/main/java/pkg/features/items/
- [ ] ItemId.java        typed id
- [ ] Item.java          aggregate root: create, change, the rules
- [ ] ItemForm.java      posted strings, parse() to typed values
- [ ] ItemStore.java     count, findPage, find, insert, update, delete
- [ ] ItemPages.java     ItemRow, IndexPage, FormPage, DetailsPage
- [ ] ItemRoutes.java    the eight routes below

src/main/jte/items/
- [ ] index.jte          signals, toolbar, delete dialog, includes table.jte
- [ ] table.jte          fragment with id="items-table": rows and pager
- [ ] fields.jte         inputs shared by create and edit
- [ ] create.jte
- [ ] edit.jte
- [ ] details.jte

src/main/resources/db/migration/
- [ ] V00n__items.sql

Wiring
- [ ] construct ItemStore and ItemRoutes in App.java, call items.register(config.routes)
- [ ] nav link in layout/page.jte
- [ ] dashboard card with the row count
```

Shared files that must already exist from scaffolding: `fragments/messages.jte`, `fragments/toast.jte`, and the `pkg.web` kit.

## Routes

| Purpose | Method | Path | Answers with |
|---------|--------|------|--------------|
| Index | GET | `/items` | Full page. Reads `?search=&page=&pageSize=`. |
| Table fragment | GET | `/items/table` | SSE: table patch, then signals patch |
| Create form | GET | `/items/new` | Full page |
| Create | POST | `/items` | Redirect with flash, or the form again with errors |
| Details | GET | `/items/{id}` | Full page |
| Edit form | GET | `/items/{id}/edit` | Full page |
| Update | POST | `/items/{id}` | Redirect with flash, or the form again with errors |
| Delete | POST | `/items/{id}/delete` | Datastar: table, signals, toast. Plain form: redirect with flash. |

Register `/items/table` and `/items/new` before `/items/{id}`.

## What happens on each interaction

| The user | The browser sends | The server does |
|----------|-------------------|-----------------|
| Opens `/items` | GET | Renders the page with state from the query string |
| Types in search | `@get('/items/table')` after 300 ms, with signals | Patches `#items-table`, patches `items` signals |
| Clicks Previous or Next | Sets `$items.page`, then `@get('/items/table')` | Same |
| Changes rows per page | Sets `$items.page = 1`, then `@get('/items/table')` | Same |
| Confirms a delete | `@post('/items/{id}/delete')` | Deletes, patches table and signals, appends a toast |
| Submits create or edit | Form POST | Parses, asks the aggregate, saves, redirects. On failure renders the form with messages. |

Nothing on the index page reloads the page except following a link.

## Adapting it to a real entity

- Rename `Item`, `items` and `/items` throughout. The signal object takes the plural name, and the string passed to `TableState.fromSignals` must match it.
- Put each field in five places: the aggregate, the form record, the store's SQL and row mapper, the row or page record, and the templates.
- A field that is not text gets parsed in `ItemForm.parse()` and nowhere else.
- A rule that needs the database goes next to the store call, as `nameIsFree` does.
- If the entity has child rows, a status workflow, or must trigger something after a change, read the matching section of [domain-modeling.md](domain-modeling.md) before writing the aggregate.

## Done means

The browser checks at the end of [crud-pages.md](crud-pages.md) pass. A feature whose pager reloads the page is not done.
