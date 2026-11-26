# Dashboard

Authenticated home. One summary card per aggregate (greenfield) or per live count the composition root already has (hydra).

## Greenfield

`GET /dashboard` loads `select count(*)` per feature. No SSE. Counts are a page load.

```java
public record DashboardPage(
        String userName,
        int itemCount
        // one int per feature as they land
) {}
```

Card: Basecoat `.card`, count, short description, link to the index. Grid `grid-cols-1 md:grid-cols-2 lg:grid-cols-3`.

Add a card when you add a feature. That is the whole scaling rule.

## hydra

The dashboard is the first proof the UI is in-process. Pass counts from `SkeletonApp` into `UiServer`:

- stored readings, credits, quarantined, drained
- scheduled meters, TOA dispatched
- optional: campaign list if any exist

Plus a Grafana button. See [observability.md](observability.md).

Do not SSE the whole dashboard on attach unless a count is expected to twitch every second (demo TOA loop). If you do, patch a `#toa-counts` fragment, not the entire layout.

## Welcome line

"Welcome back, {userName}" is enough. hydra stub: "Hydra operator".

## Quick actions

Greenfield: "Add item" link.

hydra: "Request TOA", "Start campaign", "Open Grafana".
