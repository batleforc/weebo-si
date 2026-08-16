# HyperDX dashboards

Every `*.json` file in this directory is a HyperDX dashboard that the
`clickstack-dashboards` Job keeps in sync with the instance on each ArgoCD sync
of the `monitoring` app. The file name is irrelevant; the dashboard's identity
is its `name` field.

- **Import / update** — add or edit a file, commit, sync.
- **Delete** — remove the file (`clickstack.dashboards.prune`, on by default),
  or, for a dashboard built by hand in the UI, add its name to
  `clickstack.dashboards.delete` in `values.yaml`.

The Job stamps a tag (`clickstack.dashboards.managedTag`, default
`managed-by-argocd`) on everything it creates and only ever updates or prunes
dashboards carrying it. Dashboards you build in the UI are invisible to it
unless you name them in `dashboards.delete`.

## File format

The body of a `POST /dashboards` request, i.e. `DashboardWithoutIdSchema`:

```json
{
  "name": "Cluster overview",
  "tags": [],
  "tiles": [
    {
      "id": "a1b2c3d4",
      "x": 0, "y": 0, "w": 6, "h": 3,
      "config": { "...": "chart config, see below" }
    }
  ]
}
```

`name` and `tiles` are required, `tags` is filled in for you. Server-owned keys
(`_id`, `id`, `team`, `alerts`, `provisioned`, `createdAt`/`createdBy`,
`updatedAt`/`updatedBy`) are stripped on the way in, so an unedited export
works as-is.

**Sources and connections are referenced by name, not id.** HyperDX generates
`Logs` / `Traces` / `Metrics` / `Sessions` and `Local ClickHouse` with fresh
ObjectIds when `setupTeamDefaults()` runs at registration, so no id can be
committed. Write `"source": "Metrics"` / `"connection": "Local ClickHouse"` and
the Job substitutes the real id at apply time (`source`, `connection`,
`sourceId` and `appliesToSourceIds`, anywhere in the document). An id that is
already a 24-char hex string is left alone, so an unedited export still
round-trips on the install it came from; anything else fails the run with the
list of known names.

Tile geometry is a **24-column** grid (`x`+`w` ≤ 24). `tile.config` is a union
of three shapes:

- **builder** — `source`, `select[]`, `where`, `whereLanguage`; the natural fit
  for plotting one metric. Metric series look like
  `{"aggFn": "avg", "aggCondition": "", "aggConditionLanguage": "lucene",
  "valueExpression": "Value", "metricName": "k8s.pod.cpu.usage",
  "metricType": "gauge"}`, with `aggFn: "increase"` + `metricType: "sum"` for
  Prometheus counters. `from`/`metricTables`/`connection` come from the source.
- **raw SQL** — `configType: "sql"` + `sqlTemplate` + `connection`. Needed for
  anything the builder cannot express (counting series, `argMax` over labels).
  Line charts infer their axes from ClickHouse column *types*, so return one
  Date/DateTime column, one numeric column, and optionally a string column per
  series.

  The two macro families are **not** interchangeable, and the Job rejects the
  mistake rather than letting it reach the UI:

  - `$__timeFilter(col)` and friends bind to the selected range and belong in
    every raw SQL tile. A tile without one queries the whole table and silently
    ignores the time picker (the Job warns).
  - `$__timeInterval(col)` and `$__interval_s` resolve from the chart
    *granularity*, which only `line` / `bar` / `stacked_bar` / `heatmap` tiles
    have. Using either on a `number`, `table` or `search` tile fails at render
    with ``Substitution `intervalSeconds` is not set`` — a table or number tile
    should aggregate over the whole range instead of bucketing it.
- **PromQL** — `configType: "promql"` + `promqlExpression`.

## What is here

- `argocd.json` — ArgoCD control-plane health: app sync/health counts and the
  per-app table (from `argocd_app_info`), sync outcomes, reconciliation p95 and
  rate, git/redis/k8s-API traffic, per-pod CPU and memory, container restarts,
  and the namespace's error/warning logs.

  The `argocd_*` half needs the Prometheus endpoints to be scraped, which is
  opted into by the pod annotations `otelScrapeAnnotations` adds in
  `1.pulu-conf/main.go` — that is a Pulumi change, so it lands on the next
  `pulumi up`, not on an ArgoCD sync. The CPU/memory/restart/log tiles work
  today, since kubeletstats and filelog already cover every namespace.

- `node.json` — host health: CPU (total and by state), load average, memory by
  state, filesystem fill, disk throughput/IOPS/busy, network
  throughput/packets/errors, TCP connections, pods per namespace, the top pods
  by CPU and memory, container restarts, and node-wide error logs.

  Everything cumulative (`system.cpu.time`, `system.disk.*`,
  `system.network.*`) is diffed between time buckets with `lagInFrame` and the
  first bucket of each series dropped — without that, the first point reports
  the counter's entire lifetime total (eth0 read 21 GB/s before the guard was
  added). Rates then divide by `$__interval_s`, so they stay correct at any
  granularity the time picker chooses.

## Round trip: build it in the UI, then commit it

There is no export button. Get the JSON from the API with the same credentials
the Job uses:

```sh
kubectl -n monitoring run hdx-export --rm -it --restart=Never \
  --image=curlimages/curl:8.11.1 \
  --env=EMAIL="$(kubectl -n monitoring get secret clickstack-bootstrap -o jsonpath='{.data.ADMIN_EMAIL}' | base64 -d)" \
  --env=PASSWORD="$(kubectl -n monitoring get secret clickstack-bootstrap -o jsonpath='{.data.ADMIN_PASSWORD}' | base64 -d)" \
  -- sh -c 'curl -sS -c /tmp/j -o /dev/null -X POST -H "Content-Type: application/json" \
      -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" http://clickstack:8000/login/password;
    curl -sS -b /tmp/j http://clickstack:8000/dashboards'
```

Pick the dashboard you want out of the returned `data` array, drop it in a file
here, and commit. Re-importing an export of a *managed* dashboard is a no-op.

## Checking a change before it lands

Set `clickstack.dashboards.dryRun: true` and sync — the Job prints the
create/update/prune/delete it would perform and exits without writing.

An empty directory plus `prune: true` deletes every managed dashboard: that is
the intended meaning of "git is the source of truth", not a bug.
