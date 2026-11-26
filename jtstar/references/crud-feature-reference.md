# CRUD feature reference

Greenfield. hydra screens are not CRUD against a new table. For those, still steal the page shapes (index table + SSE fragment, form + validation) but the "store" is a published port.

## File checklist

```
- [ ] Item.java. Record + factory
- [ ] ItemStore.java. Jdbi
- [ ] ItemRoutes.java. Routes listed below
- [ ] ItemPages.java. Page records
- [ ] src/main/jte/items/index.jte
- [ ] src/main/jte/items/table.jte
- [ ] src/main/jte/items/create.jte
- [ ] src/main/jte/items/edit.jte
- [ ] src/main/jte/items/details.jte
- [ ] V00n__items.sql
- [ ] register(ItemRoutes) in App
- [ ] nav link in layout
- [ ] dashboard card
```

## Routes

| Page | Method | Path |
|------|--------|------|
| Index | GET | `/items` |
| Table fragment | GET | `/items/table` |
| Create form | GET | `/items/new` |
| Create | POST | `/items` |
| Details | GET | `/items/{id}` |
| Edit form | GET | `/items/{id}/edit` |
| Update | POST | `/items/{id}` |
| Delete | POST | `/items/{id}/delete` |

Javalin has no Razor `?handler=` convention. Separate paths. `/items/new` before `/items/{id}` so `new` is not parsed as an id.

## Handler summary

| Handler | Success | Error |
|---------|---------|-------|
| index GET | full page | `ErrorDetail` on the page |
| table GET | SSE patch `#items-table` | patch `#sse-message-container` |
| create/update POST | redirect + flash in session | re-render form with errors |
| delete POST from table | patch table + toast | patch message |
| delete POST from edit | redirect to index | re-render edit |

Flash: `ctx.sessionAttribute("flash", "Created")` then redirect. Index reads and clears it. That is PRG. Do not invent TempData.

Page templates: [crud-pages.md](crud-pages.md).
