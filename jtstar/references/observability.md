# Observability

Two tools, two jobs. Grafana shows numbers over time: things you watch. JtStar pages are transactional screens: things you do.

## What belongs on a JtStar page

- Creating, editing and deleting records
- Starting an action and watching that one action finish, such as "12 of 400 rows imported", patched over SSE
- Tables, forms, and the detail of one record
- A count on a dashboard card

## What does not

- A rate over the last 15 minutes
- Queue depth as a chart
- Latency percentiles
- Anything with a time axis

Those come from scraped metrics and a query language built for them. Adding a chart library to a JTE page because the tab is already open produces a second, worse Grafana.

## When the app already has Grafana

Link to it from the dashboard and do not rebuild its panels:

```html
<a class="btn-outline" href="${page.grafanaUrl()}" target="_blank" rel="noreferrer">Open Grafana</a>
```

Read the URL from the environment (`GRAFANA_URL`). Do not commit a hostname in a template.

## Greenfield

Do not stand up Prometheus on the first day unless the user asks. A dashboard card with `select count(*)` is enough to start.

When they want rates, add `io.micrometer:micrometer-registry-prometheus`, expose a `/metrics` route that returns the registry's scrape text, add that path to the public list in `SessionAuth` or protect it at the network level, and point them at Grafana. The graph is drawn there.
