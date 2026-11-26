# Dashboard

> Placeholders: `pkg` is the Java package. See SKILL.md.

The page a signed-in user lands on. One summary card per feature.

## Route

`GET /dashboard` loads one count per feature and renders the page. The counts are read when the page loads. No SSE.

```java
public record DashboardPage(
        String userName,
        String csrfToken,
        int itemCount
        // one count per feature as features land
) {}
```

`DashboardRoutes` takes the stores it needs counts from in its constructor, calls `itemStore.count("")`, and renders `dashboard/index.jte` with the page record.

## Layout

- A line of welcome: "Welcome back, ${page.userName()}".
- A grid of cards: `grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6`.
- Each card is a Basecoat `card` with the count, a one-line description and a link to the feature's index.

```html
<div class="card">
    <header>
        <h2>Items</h2>
        <p>Things you sell</p>
    </header>
    <section>
        <p class="text-3xl font-semibold">${page.itemCount()}</p>
    </section>
    <footer>
        <a href="/items" class="btn-outline">View items</a>
        <a href="/items/new" class="btn-primary">Add item</a>
    </footer>
</div>
```

## Growing it

Add a card when you add a feature. That is the whole rule.

If one number on the dashboard has to move while the page is open, wrap that number in a fragment and patch it with a live view. Leave the other cards alone. See [datastar-sse.md](datastar-sse.md).

Charts and rates do not go here. See [observability.md](observability.md).
