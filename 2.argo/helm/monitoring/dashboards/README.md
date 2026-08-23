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

`tile.config.onClick` makes a row clickable, which is how a metrics tile hands
over to the logs or traces it cannot show itself:

```json
"onClick": {
  "type": "search",
  "target": { "mode": "template", "template": "Logs" },
  "whereTemplate": "ResourceAttributes['k8s.pod.name'] = '{{Pod}}'",
  "whereLanguage": "sql"
}
```

`whereTemplate` is a Handlebars template over the **clicked row**, so `{{Pod}}`
is the value of the column aliased `"Pod"` — which is why the columns a template
reads are aliased without spaces. The search opens on the dashboard's current
time range.

`target.mode: "template"` resolves the source by **name** at click time, in the
browser, so `"Logs"` / `"Traces"` can be committed as-is. This is a different
mechanism from the `source` / `connection` substitution above and does not go
through it — the Job only rewrites the `source`, `connection`, `sourceId` and
`appliesToSourceIds` keys, none of which appear inside `onClick`. Use
`mode: "template"` rather than `mode: "id"`, whose ObjectId is per install and
would be rewritten by nothing. `type` may also be `dashboard` (same fields) or
`external` (`urlTemplate`, must render to an absolute http(s) URL). Supported
from HyperDX 2.32.

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

- `consumers.json` — who is eating the node, and what that workload has to say
  for itself. One master table ranking containers by CPU with memory, restarts,
  log and span counts side by side, then a section per axis (CPU, memory,
  writable layer and page faults, network, telemetry volume), then four tiles
  restricted to the top ten CPU consumers: their log and span totals, their
  recent errors, and their slowest spans.

  **A consumer here is a container, not a host process**, and that is a data
  constraint rather than a naming choice. kubeletstats measures per container
  (`container.cpu.usage`, `container.memory.working_set`) and every record it
  emits carries `k8s.pod.name` — which is the only reason the drill-down works
  at all. The OS processes on the node are not collected: hostmetrics' `process`
  scraper is off, and turning it on would not help, because its series are keyed
  on `process.pid` / `process.executable.name` with no cgroup or pod attribute,
  so a host PID joins to no log and no trace. The `process.*` attributes that do
  appear in `otel_traces` come from the Node SDK inside `hdx-oss-api`, not from
  the node, and cover that one workload.

  Every table is clickable (`onClick`, documented above): a row opens Search on
  that container's logs or traces over the same time range. Tables that rank
  pods rather than containers — network, telemetry volume — open the whole pod,
  because `k8s.pod.network.io` is a per-pod counter with no container
  dimension; the slowest-spans table opens its own `TraceId`.

  The drill-down tiles resolve their top-ten set in the query, with
  `$__timeFilter` on both halves, so the set follows the time picker instead of
  being a committed list of workloads. They read `otel_logs` through a tuple
  `IN` on the materialised `k8s.pod.name` / `k8s.container.name` columns, which
  is an index lookup rather than a join — the master tile stays under a second
  against a table taking a million rows an hour. A `LEFT JOIN` for the counts is
  what keeps a silent container in the ranking: it shows `0` logs rather than
  dropping out.

  Three figures are easy to misread. `% req` and `% lim` are blank, not zero,
  when a container declares no request or limit — blank means unbounded.
  `Restarts` is the lifetime count `kubectl get pod` shows, matching
  `node.json`'s convention, not restarts within the selected range. And `Lines`
  is not `Rows`: otel-node's `logdedup` processor collapses byte-identical
  records inside `otel.node.dedupInterval` and stamps the survivor with
  `log_count`, so `Rows` counts what ClickHouse stores while `Lines` sums
  `log_count` back up to what the workload printed. Rows written before dedup
  was enabled carry no attribute, the map lookup returns `''`, and
  `greatest(toUInt64OrZero(…), 1)` reads them as the single line they are — so
  the two columns simply agree on older data rather than breaking.

  There is no per-container block-IO counter in kubeletstats, so the disk
  section reads pressure two ways instead: `container.filesystem.usage`, the
  writable layer a container wrote outside any volume, and major page faults,
  the reads that had to reach disk. Claims and volumes live in `storage.json`.

- `egress.json` — everything the cluster calls that is not the cluster: call
  and failure counts, failure rate, p95, the per-host dependency table, who
  calls what, status codes over time, and the recent-failure / slowest-call
  tables.

  Built entirely from OBI's *client* spans (`SpanKind = 'Client'`), which carry
  `server.address` with the real hostname because OBI decodes TLS. Nothing
  needs to be scraped for this to work.

  A peer counts as external when it is neither a private address
  (10/8, 172.16/12, 192.168/16, 127/8, 169.254/16, `fc00::/7`, `fe80::/10`,
  `::1`) nor an in-cluster name. In-cluster names are recognised by suffix:
  `.cluster.local`, `.svc`, `.local`, `.weebo.poc`, or a last label that is a
  namespace in this cluster — that list comes from `otel_logs_kv_rollup_15m`,
  so it covers every namespace that logs, updates itself, and costs nothing
  (reading it out of `otel_traces` instead blew the 4.5 GiB query limit).
  Two consequences worth knowing: **the ingress domain is hardcoded**, so
  renaming `weebo.poc` means editing these queries; and the node's own IP is
  public (OVH), so if a workload ever dials the node IP directly it reads as
  external.

  "Failed" is `StatusCode = 'Error'`, OTel's own verdict, which covers HTTP,
  DB and RPC peers alike. It includes the `401` half of a registry token
  handshake — `ghcr.io` sitting near 33% "failed" with a matching count of
  `200`s is the normal HEAD → 401 → auth → 200 dance, not an outage. The
  "Unanswered calls" tile is the unambiguous one: an errored span with no
  status code at all is a call that got no response.

- `dependencies.json` — the call map: every edge OBI observed, in one place.
  Counts, distinct edges, workloads, external peers and the share of traffic
  that leaves; calls by zone as a pie and over time; the full adjacency table
  (zone → caller → peer → protocol, with calls, failures and latency); fan-out
  per workload beside inbound load per service; every failing edge with the
  status codes it returned; and a search tile of recent failed client spans.

  Peers are bucketed into four zones — `kube-apiserver`, `in-cluster`,
  `loopback`, `external` — by the same rules `egress.json` uses to decide what
  counts as outside, so the two dashboards always agree on the boundary.

  Two tile shapes appear here for the first time. **Markdown** tiles
  (`displayType: "markdown"` + a `markdown` string) carry the legend and the
  section headers; the renderer skips the query for them, but the API's schema
  still rejects a tile with no `source`/`connection`/`sqlTemplate`, hence the
  `SELECT 1 … LIMIT 1` placeholder on each. A **pie** tile carries the zone
  split. Both are supported from HyperDX 2.32.

  The counting tiles use `uniq()` rather than `countDistinct()` on purpose:
  ClickHouse's exact implementation builds the full set of edge strings and
  tips this instance over its 4.5 GiB query limit, while an HLL is exact at
  two-figure cardinality.

- `storage.json` — which pod is using the disks. Fill and growth per
  filesystem with a days-to-full projection, PVC usage per pod, Longhorn's own
  per-volume accounting, pod ephemeral usage, and the SSD's SMART attributes.

  Three sources, deliberately kept apart because they measure different things:
  kubelet's `k8s.volume.*` (what the filesystem inside a claim reports),
  Longhorn's `longhorn_volume_actual_size_bytes` (what a thin-provisioned
  volume actually costs on disk, snapshots included), and
  `k8s.pod.filesystem.usage` (writable layers and emptyDirs, which belong to no
  claim). Only the last one works on a fresh checkout; the other two need the
  enablement below.

  **`local-path` claims are not attributable to a pod, and cannot be made so
  from here.** Kubelet only reports usage for volumes whose driver measures
  them: the four longhorn claims carry a `pvcRef` in `/stats/summary`, the
  hostPath-backed local-path ones carry nothing. Their bytes land in the `/var`
  total and in the *Unattributed on /var* tile, next to the container image
  store. Moving a claim to the `longhorn` class is what makes it visible.

  Two mountpoints are hardcoded in the top-row tiles — `/var` and
  `/var/mnt/staticdisk`, the latter being `defaultDataPath` in the Longhorn
  Application. Change that path and these two tiles need editing; the
  filesystem table below them is generic and needs nothing.

  Enablement, both of which this commit also makes:
  - `metric_groups: [… volume]` + `k8s_api_config` on the kubeletstats
    receiver in `templates/otel/node-collector.yaml`, plus PVC/PV read rules in
    `clusterRole.rules` — the receiver fails at startup without them. ArgoCD
    sync.
  - `annotations` on the Longhorn Application opting longhorn-manager's `:9500`
    into otel-node's discovery. Also an ArgoCD sync, of the `storage` app.

- `network.json` — what gets dropped, in two halves.

  The NIC half (`system.network.dropped`, `system.network.errors`,
  `k8s.pod.network.errors`) works today off otel-node. Same counter handling as
  `node.json`, plus series that never moved are filtered out of the line charts
  so an idle cluster shows an empty chart instead of a legend full of flat
  zeroes.

  The `Hubble ·` half stays empty until `hubble.metrics.enabled` is set in
  `1.pulu-init/cilium-values.yaml` and scraped — which is a Pulumi change
  (`task pulunit:up`), not an ArgoCD sync. It is the only source here for
  *policy* drops and DNS failures: OBI never sees them, because a denied or
  unresolved connection completes no protocol exchange and so produces no span.
  `action = 'dropped'` is the denial (Hubble lowercases the flow verdict).

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
