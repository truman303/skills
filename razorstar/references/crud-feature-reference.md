# CRUD Feature Reference

Complete walkthrough for building a CRUD feature, based on the canonical FrequencyAllocationPlans implementation.

## File Checklist

```
Feature Implementation:
- [ ] Domain model (Models/Item.cs) — aggregate + ID + errors + DTO + repo + EF config
- [ ] Create command (Commands/CreateItemCommand.cs)
- [ ] Update command (Commands/UpdateItemCommand.cs)
- [ ] Delete command (Commands/DeleteItemCommand.cs)
- [ ] Get all query (Queries/GetItemsQuery.cs)
- [ ] Get by ID query (Queries/GetItemByIdQuery.cs)
- [ ] DI registration (DependencyInjection.cs)
- [ ] DbContext DbSet registration
- [ ] Index page + table partial (Pages/Items/Index.cshtml, _ItemsTable.cshtml)
- [ ] Create page (Pages/Items/Create.cshtml)
- [ ] Edit page (Pages/Items/Edit.cshtml)
- [ ] Details page (Pages/Items/Details.cshtml)
- [ ] Register AddItemServices() in Program.cs
```

## Page-Specific References

Each page type has its own reference with complete PageModel and Razor template:

- [crud-index-page.md](crud-index-page.md) — Table with SSE fragments, search, pagination, inline delete
- [crud-create-page.md](crud-create-page.md) — Form with validation, two-column layout, sidebar guidelines
- [crud-edit-page.md](crud-edit-page.md) — Change tracking, unsaved changes warning, danger zone, delete modal
- [crud-details-page.md](crud-details-page.md) — Read-only view, Quick Actions sidebar, statistics

## Routing Convention

Detail and Edit pages live in subfolders of `Pages/Items/`, so their routes include the page name:

| Page | File | Route |
|------|------|-------|
| Index | `Pages/Items/Index.cshtml` | `/Items` |
| Create | `Pages/Items/Create.cshtml` | `/Items/Create` |
| Details | `Pages/Items/Details.cshtml` (`@page "{id}"`) | `/Items/Details/{id}` |
| Edit | `Pages/Items/Edit.cshtml` (`@page "{id}"`) | `/Items/Edit/{id}` |

**Always use tag helpers** (`asp-page="Details" asp-route-id="@item.Id"`) for links rather than hardcoded URLs. If you must hardcode, use the full path (e.g., `/Items/Details/{id}`, not `/Items/{id}`).

## Handler Pattern Summary

| Handler | Success | Error |
|---------|---------|-------|
| `OnGetAsync` | Render page | Set `ErrorDetails` |
| `OnGetTableFragmentAsync` | `CreateAndPatchPartialAsync` | `CreateAndPatchErrorMessageAsync` |
| `OnPostAsync` (Create/Edit) | `TempData` + `RedirectToPage` | Set `ErrorDetails` + render page |
| `OnPostDeleteAsync` (Edit) | `TempData` + `RedirectToPage("Index")` | Set `ErrorDetails` + render page |
| `OnPostDeleteAsync` (Index) | `CreateAndPatchSuccessToastAsync` | `CreateAndPatchErrorMessageAsync` |
