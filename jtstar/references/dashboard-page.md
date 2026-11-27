# Dashboard

> Placeholders: `pkg` is the Java package. See SKILL.md.

The page a signed-in user lands on. One summary card per feature.

## Route

`GET /dashboard` loads one count per feature and renders the page. The counts are read when the page loads. No SSE.

```java
package pkg.features.dashboard;

import io.javalin.http.Context;
import io.javalin.router.JavalinDefaultRoutingApi;
import java.util.Map;
import pkg.features.items.ItemStore;
import pkg.web.SessionAuth;

public final class DashboardRoutes {
    private final ItemStore itemStore;

    public DashboardRoutes(ItemStore itemStore) {
        this.itemStore = itemStore;
    }

    public void register(JavalinDefaultRoutingApi routes) {
        routes.get("/dashboard", this::index);
    }

    private void index(Context ctx) {
        ctx.render("dashboard/index.jte", Map.of("page", new DashboardPage(
                SessionAuth.userName(ctx),
                SessionAuth.csrfToken(ctx),
                itemStore.count(""))));
    }

    /** One count per feature. Add a field when a feature lands. */
    public record DashboardPage(String userName, String csrfToken, int itemCount) {}
}
```

During scaffolding there is no feature yet. Build `DashboardRoutes` with no store and a page record without counts, then add `ItemStore` and `itemCount` when the first feature lands.

## `dashboard/index.jte`

```html
@import pkg.features.dashboard.DashboardRoutes.DashboardPage
@param DashboardPage page

@template.layout.page(
    title = "Dashboard",
    userName = page.userName(),
    csrfToken = page.csrfToken(),
    currentPage = "Dashboard",
    content = @`
        <p class="text-muted-foreground mb-6">Welcome back, ${page.userName()}.</p>

        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            <div class="card">
                <header>
                    <h2>Items</h2>
                    <p>Things you sell</p>
                </header>
                <section>
                    <p class="text-3xl font-semibold">${page.itemCount()}</p>
                </section>
                <footer class="flex gap-2">
                    <a href="/items" class="btn-outline">View items</a>
                    <a href="/items/new" class="btn-primary">Add item</a>
                </footer>
            </div>
        </div>
    `
)
```

Each card is a Basecoat `card` with the count, a one-line description and links into the feature.

## Growing it

Add a card when you add a feature. That is the whole rule.

If one number on the dashboard has to move while the page is open, wrap that number in a fragment and patch it with a live view. Leave the other cards alone. See [datastar-sse.md](datastar-sse.md).

Charts and rates do not go here. See [observability.md](observability.md).
