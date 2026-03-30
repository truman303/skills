# Agent Skill Issues

## RazorStar Issues

The skill is currently quite opinionated which could make it inflexible. Over time lets whittle it down to the bare essentials and make it more flexible.

### ISSUE 1: The landing flow is not working correctly [RESOLVED]

When landing on root https://localhost:7264/ we get a 401 and are not redirected to the login page.

**Fix:** Added `AllowAnonymousToPage("/Index")` to Razor Pages conventions. Updated `Index.cshtml.cs` to check auth state and redirect unauthenticated users to `/Auth/Login` instead of `/Dashboard/Index`. Changed in `program-cs.md`, `login-page.md`, and `project-scaffolding.md`.

### ISSUE 2: Script for post run steps e.g. migrations, seeding, building and running the app [RESOLVED]

- Starting the development environment (postgres container)
- Creating and running first migration
- Other?

**Fix:** Tightened Phase 3 in SKILL.md with a clear numbered checklist table (start dev env, create migration, run app, open URL, login).

### ISSUE 3: DateTimeOffset confusion [RESOLVED]

The following error is thrown when trying to save an item:

- ArgumentException: Cannot write DateTime with Kind=Unspecified to PostgreSQL type 'timestamp with time zone', only UTC is supported. Note that it's not possible to mix DateTimes with different Kinds in an array, range, or multirange. (Parameter 'value')

This is because the input dates are Kind=Unspecified on a specific input DateTime field. The system uses DateTimeOffset for all genuine date time values. Where only a date is needed, use `DateOnly` instead of `DateTime`. Please update the skill to highlight this. Also include it in the Gotchas section at the end of the skill.

**Fix:** Expanded Gotchas section in SKILL.md with full error message, rules, and alternatives. Added note and `DateOnly Today` property to `IClock` in `shared-domain.md`.

### Issue 4: Details page links are not working correctly [RESOLVED]

The details page links were broken. I had to change this `/Items/{id}` to this `/Items/Details/{id}`, since thats how the page setup is. Please fix this in the skill.

**Fix:** Added Routing Convention table to `crud-feature-reference.md` showing correct routes for all page types. Added Razor Pages Routing gotcha in SKILL.md.

### Issue 5: Item Edit page does not show existing values on the form [RESOLVED]

The edit item page does not show the existing values for the item.

**Fix:** Added complete `Edit.cshtml` template to `crud-edit-page.md` with `value="@Model.PropertyName"` on all form inputs and `checked` attribute on toggles, ensuring server-rendered HTML displays values before DataStar initialises.

### Issue 6: The guidelines card minimise button closes the card [RESOLVED]

This is not right, when a card is minimised, just the header and the minimise/maximise button should be visible.

**Fix:** Moved `data-show` from the card wrapper to the `<section>` element in `crud-create-page.md`, `crud-edit-page.md`, and `ui-component-patterns.md`. Added explicit "Collapsible Card" pattern to UI patterns reference.

### Issue 7: Include dark mode toggle on header [RESOLVED]

The header should include a dark mode toggle out of the box.

**Fix:** Added moon/sun toggle button to the layout header in `project-scaffolding.md`. Toggles `dark` class on document root and persists to localStorage. Included in all three layout variants (sidebar, top nav, creative).

### Issue 8: Add a profile link to the header [RESOLVED]

The profile link should be a ghost button with the username on the right of the header.

**Fix:** Added ghost profile button with user icon and `data-text="$user.name"` next to dark mode toggle in all layout templates.

### Issue 9: Spacing between buttons on the item create page [RESOLVED]

The spacing between the buttons on the item create page is too small or non-existent.

**Fix:** Added `flex items-center justify-end gap-3` to all card `<footer>` elements in `crud-create-page.md`, `crud-edit-page.md`, and `ui-component-patterns.md`.

### Issue 10: The workflow should mention the images and theme [RESOLVED]

The user should be advised to review and change the images and theme in the references folder before creating a new razorstar app. Describe to the use what is required including image size and type. Mention that themes can be copied from [tweakcn](https://tweakcn.com), for example.

**Fix:** Added Phase 1 Step 1C "Review and Customise Theme & Images" to SKILL.md with recommended image sizes, formats, and a link to tweakcn for theme generation.

### Issue 11: The skill should support side menu or top menu [RESOLVED]

The skill should support both side menu and top menu. The user should be able to choose which menu they want to use during the build process.

**Fix:** Added Phase 1 Step 1D "Choose Navigation Layout" with three options: Sidebar (default), Top Nav, and Creative (no navigation chrome). Added complete layout templates for all three in `project-scaffolding.md`.
