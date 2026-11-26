# Observability

hydra-v3 already made this call. JtStar follows it even on greenfield.

**Grafana owns anything numeric-over-time** (things you watch). **JTE + Datastar owns transactional screens** (things you do).

## hydra-v3, already wired

| Piece | Where |
|-------|--------|
| Micrometer Prometheus registry | `app-skeleton` |
| Scrape | `http://localhost:9464/metrics` (`METRICS_PORT`) |
| Prometheus | `http://localhost:9090` |
| Grafana | `http://localhost:3000` (`admin`/`admin`), dashboard **Hydra TOA** (`uid: hydra-toa`) |
| Counters | `MetricsAuditLog` (`TOA_DISPATCHED`, delivered, redispatched, exhausted, …) |
| Gauges | `HydraMetrics` (queue depth, task state, schedule membership, ingest totals) |

The operator dashboard links to Grafana. It does not reimplement those panels.

```html
<a class="btn btn-outline" href="http://localhost:3000/d/hydra-toa/hydra-toa" target="_blank" rel="noreferrer">
    Open Grafana
</a>
```

In production the Grafana URL comes from env `GRAFANA_URL`. Do not hardcode localhost in a committed template if they have a real env. For the play rig, localhost is the truth.

## What belongs on a JtStar page

- Trigger a campaign, request TOA, edit a registry row, ack an alarm
- Live *progress of a thing the operator started* (12/400 delivered), patched over SSE
- Tables, forms, troubleshooting for one meter

## What does not

- Ingest rate over 15 minutes
- Queue depth charts
- Consumer-group lag
- Per-driver attempt heatmaps

Those are scrape + PromQL. Adding a chart library to JTE because the tab is already open is how you get a second, worse Grafana.

## Greenfield

Do not stand up Prometheus on day one unless they ask. A summary card with `select count(*)` is enough. If they later want rates, add Micrometer + a scrape endpoint and tell them to run Grafana. Do not draw the graph in Datastar.
