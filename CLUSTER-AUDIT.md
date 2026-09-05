# Cluster audit — `weebo4-cluster`

**Date**: 2026-09-05 · **Node**: `talos-r2k-rp0` (Talos v1.13.5, k8s v1.36.2, containerd 2.2.5) · **Topology**: single node, control-plane + workload
**Tools**: `kubectl top` / API metrics, Popeye v0.x (`-A`), Kubescape (ClusterScan / NSA / MITRE)

| Scanner | Result |
|---|---|
| Popeye | **Score 80 — grade B** |
| Kubescape | **Compliance 73.1%** — ClusterScan 11.7, NSA 26.4, MITRE 17.2 |

---

## 1. Executive summary

> **Progress — 2026-09-05.** Findings 1, 2, 3, 5 and 6 are resolved (commits `7b28c7e3`, `74365b3e`, plus live cleanup); action-plan items 7 and 12 are settled or were already done. **3 of the 8 headline findings remain open** — 4 (network policy), 7 (apiserver request) and 8 (`:latest` tags / default ServiceAccounts). Corrections made while implementing are marked inline — two of the original findings did not survive measurement.

The cluster is **not resource-constrained** — it runs at 15% CPU and 27% memory of a 12-core / 61 GiB node. The real problems are **governance and storage**, not capacity:

| # | Finding | Severity |
|---|---|---|
| 1 | ~~Longhorn ClickHouse volume at **21.4 GB of 21.5 GB** allocated, no filesystem trim~~ — ✅ **RESOLVED**, 13.25 GB reclaimed | 🔴 → Done |
| 2 | ~~**49/77 workloads have no memory limit, 57/77 no CPU limit**~~ — ✅ **RESOLVED** by a Kyverno-generated LimitRange in every namespace (`74365b3e`) | 🔴 → Done |
| 3 | ~~ClickHouse `mark_cache_size` + `index_mark_cache_size` at the 5 GiB default inside a 4.5 GiB budget~~ — ✅ **RESOLVED**, capped at 512 MiB (`74365b3e`). *Downgraded from High after measuring: total marks are 12.75 MiB, so it could never fill* | 🟡 → Done |
| 4 | 18 of 24 namespaces have **zero network policy** — flat east-west network | 🟠 High |
| 5 | ~~Kyverno runs 4 controllers (**428 MiB / 22m**) to enforce **one Audit-only policy**~~ — ✅ **SETTLED: keep it.** It now generates the LimitRanges of finding 2, so the background-controller is load-bearing. Open work is extending it to finding 8 rather than editing 40 charts | 🟠 → Decided |
| 6 | ~~KubeBlocks / MongoDB-Enterprise leftovers~~ — ✅ **RESOLVED**: 52 ConfigMaps (not 29), 21 orphan Helm release records, 1 orphan Service and the `zitadel` namespace deleted. Dead images remain (cosmetic) | 🟡 → Done |
| 7 | `kube-apiserver` at **2.35 GiB** against a 512 Mi request (460%) with no limit | 🟡 Medium |
| 8 | ~~11 workloads pinned to `:latest`~~ ✅ **pinned + under Renovate**; 10 pods on the `default` ServiceAccount still open | 🟡 Partial |

---

## 2. Capacity baseline

### Node

| Resource | Capacity | Allocatable | Requested | Limits | **Actually used** |
|---|---|---|---|---|---|
| CPU | 12 | 11 950m | 5 211m (43%) | 8 950m (74%) | **1 819m (15%)** |
| Memory | 62.7 GiB | 58.1 GiB | 6.7 GiB (11%) | 13.5 GiB (23%) | **15.9 GiB (27%)** |
| Pods | 110 | 110 | — | — | 78 |
| Disk (`/`) | 443 GiB | — | — | — | **48.8 GiB (11%)** — of which **36.2 GiB is the image cache** |

Memory PSI (`some`/`full` avg300) = **0** → no memory pressure whatsoever. There is a large amount of headroom; the recommendations below are about **safety and predictability**, not about reclaiming capacity.

> ⚠️ Requests (6.7 GiB) are *below* real usage (15.9 GiB). The scheduler's view of this node is wrong by more than 2×. On a single node that is tolerable; the moment a second node joins, scheduling will be badly skewed.

### Consumption by namespace

| Namespace | CPU | Memory | Share of used RAM |
|---|---:|---:|---:|
| `kube-system` | 251m | 3 433 Mi | 29.4% |
| `monitoring` | 457m | 2 684 Mi | 23.0% |
| `auth` | 115m | 1 438 Mi | 12.3% |
| `argocd` | 84m | 1 001 Mi | 8.6% |
| `longhorn` | 163m | 710 Mi | 6.1% |
| `obi` | 146m | 703 Mi | 6.0% |
| `hook` (kyverno) | 22m | 428 Mi | 3.7% |
| `cert-manager` | 6m | 313 Mi | 2.7% |
| `external-secrets` | 3m | 241 Mi | 2.1% |
| `traefik` | 1m | 201 Mi | 1.7% |
| `database` | 14m | 183 Mi | 1.6% |
| `vault-operator` | 3m | 154 Mi | 1.3% |
| `vault` | 13m | 66 Mi | 0.6% |
| others (netbird, s3, dex, …) | ~17m | ~133 Mi | 1.1% |
| **Total** | **1 295m** | **11 688 Mi** | (+ ~4 GiB kubelet/containerd/system) |

### Top 12 consumers

| Pod | CPU | Memory | Request (mem) | Limit (mem) | Verdict |
|---|---:|---:|---|---|---|
| `kube-system/kube-apiserver` | 295m | **2 349 Mi** | 512 Mi | *none* | 460% over request |
| `monitoring/clickstack-clickhouse-0-0-0` | 237m | **1 437 Mi** | 1 Gi | 5 Gi | 139% over request |
| `auth/authentik-server` | 28m | **759 Mi** | *none* | *none* | unbounded |
| `argocd/argocd-application-controller-0` | 139m | **750 Mi** | *none* | *none* | unbounded |
| `obi/…-ebpf-instrumentation` | 137m | **674 Mi** | *none* | *none* | unbounded, privileged, hostPID |
| `monitoring/clickstack` (HyperDX app) | 17m | 510 Mi | *none* | *none* | unbounded |
| `auth/authentik-worker` | 70m | 398 Mi | *none* | *none* | unbounded |
| `longhorn/instance-manager-b82c8…` | 87m | 382 Mi | 478m CPU / no mem | *none* | unbounded |
| `auth/authentik-postgresql-0` | 29m | 255 Mi | *none* | *none* | unbounded |
| `monitoring/clickstack-mongodb-0` | 32m | 209 Mi | 800 M (2 ctr) | 1000 M | OK |
| `longhorn/longhorn-manager` | 40m | 209 Mi | 256 Mi | *none* | 81% of request |
| `kube-system/cilium-agent` | 56m | 208 Mi | *none* | *none* | unbounded |

---

## 3. Findings per component

### 3.1 🔴 Storage — Longhorn space amplification (**critical**)

| Volume | PVC | Declared | **Longhorn actual** | Used inside FS |
|---|---|---:|---:|---:|
| `pvc-a5cda587…` | `clickhouse-storage-…-0-0-0` | 20 Gi | **21.43 GB (99.8%)** | **7.6 G** |
| `pvc-68afed44…` | `…-keeper-0-0` | 5 Gi | 0.96 GB | — |
| `pvc-a79f3ba8…` | `data-volume-mongodb-0` | 10 Gi | 0.87 GB | — |
| `pvc-8b5950ae…` | `logs-volume-mongodb-0` | 1.9 Gi | 0.23 GB | — |

ClickHouse writes and TTL-drops ~350 MiB/day on a 7-day retention. Every block it has *ever* touched stays allocated in the Longhorn replica because nothing issues a `fstrim`. The volume is now **effectively full at the block layer** even though the filesystem is 39% used. Longhorn's `storage-over-provisioning-percentage` is `100`, so it cannot silently borrow more.

> ✅ **RESOLVED 2026-09-05** (commit `7b28c7e3`). `removeSnapshotsDuringFilesystemTrim: true` plus a weekly `filesystem-trim` RecurringJob (`0 3 * * 0`, `default` group, concurrency 1) landed in `2.argo/helm/storage/`, and a manual run reclaimed **13.25 GB**: ClickHouse **21.43 → 8.64 GB** (99.8% → 40.2% allocated), mongodb data 0.87 → 0.49, mongodb logs 0.23 → 0.15. Fully online — ClickHouse never restarted, 319 parts / 468M rows intact, zero checksum errors. Space returned to `default-disk-081100000000` (`/var/mnt/staticdisk`), not the root fs, which is why `node.fs` looks unchanged.

**Actions**
1. ~~Run a filesystem trim on the volume.~~ **Done** — 13.25 GB reclaimed.
2. ~~Set `remove-snapshots-during-filesystem-trim = true`.~~ **Done** — `defaultSettings.removeSnapshotsDuringFilesystemTrim` in `templates/longhorn/longhorn.yaml`. Volumes keep `unmapMarkSnapChainRemoved: ignored`, so they inherit it.
3. ~~Add a weekly `filesystem-trim` RecurringJob.~~ **Done** — `templates/longhorn/recurring-job.yaml`.
4. Consider raising `storage-over-provisioning-percentage` to 200 — with 423 GB free on the node and 1 replica per volume, 100% is needlessly tight.

> ⚠️ All four Longhorn volumes are `numberOfReplicas: 1` on a single node. That is correct for the topology, but it means **Longhorn provides zero redundancy here** — it is buying you snapshots and volume expansion only. `local-path` (used by `vault`, `auth/postgresql`) has `allowVolumeExpansion: false`, which is why the split exists; that is a reasonable design, just be explicit that "Longhorn" ≠ "replicated" today.

### 3.2 🔴 Resource governance (**critical**)

Popeye: **116 × POP-106** (no requests/limits) · **11 × POP-107** (no limits).
Kubescape: **C-0270 CPU limits — 25% compliance (57/77 failing)** · **C-0271 memory limits — 36% compliance (49/77 failing)**.

On a **single-node** cluster with no memory limits and no `Guaranteed`/`Burstable` separation, one runaway container evicts the control plane. This is the single highest-impact structural risk.

Workloads with **no requests and no limits at all**: all of `argocd`, all of `auth` (incl. `authentik-postgresql`), all of `cert-manager`, `external-secrets`, `dex`, `traefik`, `local-path-storage`, `hubble-*`, `cilium*`, `longhorn/csi-*`, `longhorn-ui`, `clickstack`, `clickstack-otel-collector`, `obi`, `vault-webhook`, `cnpg-cloudnative-pg`.

**Actions**
1. Set **memory limits everywhere** first (CPU limits are the lower priority — CPU throttling hurts more than it helps for controllers). Suggested starting points from observed usage × 2:

   | Workload | `requests.memory` | `limits.memory` |
   |---|---|---|
   | `argocd-application-controller` | 768Mi | 1536Mi |
   | `authentik-server` | 768Mi | 1536Mi |
   | `authentik-worker` | 512Mi | 1Gi |
   | `authentik-postgresql` | 256Mi | 512Mi |
   | `clickstack` (HyperDX) | 512Mi | 1Gi |
   | `obi` ebpf | 768Mi | 1536Mi |
   | `traefik` | 256Mi | 512Mi |
   | `cilium-agent` | 256Mi | 512Mi |
   | `cert-manager` (×3) | 128Mi | 256Mi |
   | `external-secrets` (×3) | 192Mi | 384Mi |
   | remaining controllers | 64–128Mi | 128–256Mi |

2. Add a **`LimitRange` per namespace** as a backstop so anything deployed without limits still gets one.

   > ⚠️ **Corrected 2026-09-05 — the 512Mi default first published here was wrong and would have caused an outage.** Measured against actual usage, a 512Mi default limit would have OOMKilled `authentik-server` (761 Mi), `argocd-application-controller` (736 Mi), `obi` (680 Mi) and the HyperDX `clickstack` app (512 Mi, exactly at the boundary) — and not at rollout. A LimitRange applies only at pod admission, so each would have died silently at its next restart, whenever that happened to fall.

   ```yaml
   apiVersion: v1
   kind: LimitRange
   metadata: {name: default-resources}
   spec:
     limits:
     - type: Container
       default:        {memory: 2Gi}          # 2.7x the largest unlimited container
       defaultRequest: {memory: 64Mi, cpu: 10m}  # floor only; no CPU *limit* by design
   ```

   **Generated by Kyverno, not shipped as manifests.** The first implementation of this put 17 LimitRange manifests in the `main` app with an explicit namespace list. That was wrong for this repo: the namespaces are created by ~15 different Applications, so the manifests raced their own targets on a cold bootstrap and would have had to be disabled for the first sync and re-enabled afterwards — defeating the point of a lab that can be torn down and rebuilt in one command.

   A Kyverno `generate` rule has no ordering at all: `generateExisting: true` backfills whatever namespaces already exist whenever Kyverno starts, and the admission path catches everything created later. `synchronize: true` recreates the LimitRange if it is deleted, and removes it when the policy goes away, so teardown leaves nothing behind. It also covers namespaces added in future without anyone remembering to edit a list.

   > ⚠️ **`failurePolicy: Ignore` is load-bearing.** A generate rule on `Namespace` makes Kyverno register a webhook on namespace CREATE. At Kyverno's default `Fail`, a Kyverno that is down or not yet up **blocks namespace creation cluster-wide** — a far worse bootstrap deadlock than the one this replaced. Verified on the live cluster: the default lands on `validate.kyverno.svc-fail`, and `failurePolicy: Ignore` moves it to `validate.kyverno.svc-ignore`.

   Lives in `2.argo/helm/hook/sub/templates/default-limits.yaml`, tunables in that chart's `values.yaml`. Kyverno's background-controller already ships `create/update/patch/delete` on `limitranges`, so no extra RBAC.

   **Two namespaces are excluded on purpose:**
   - **`kube-*`** — Talos' static control-plane pods take their cgroups from the on-disk manifests, not the mirror Pod the API server sees. A default here would display a limit that nothing enforces, which reads as solved while `kube-apiserver` stays unbounded. Its 2.5 GiB belongs in the Talos machine config. The glob also covers `kube-public` and `kube-node-lease`.
   - **`longhorn`** — upstream ships `instance-manager` without a memory limit deliberately: hitting one detaches every volume on the node, taking ClickHouse and MongoDB storage with it. Its memory also scales with volume count and size, so any number picked today expires quietly.

   > ✅ **Applied 2026-09-05** (`74365b3e`). 19 LimitRanges generated — `argocd, auth, cert-manager, cilium-secrets, database, default, dex, external-secrets, kubelet-serving-cert-approver, local-path-storage, monitoring, netbird, obi, s3, traefik, vault, vault-infra, vault-operator` (plus `zitadel`, since deleted with its namespace — now 18). `kube-*` and `longhorn` correctly skipped, webhook confirmed on `validate.kyverno.svc-ignore`, no OOMKills. First evidence it works: the ClickHouse pod, recreated minutes later, came back carrying the `cpu: 10m` request it had never had.

   Coverage: **26 of the 51 unlimited containers**, plus every namespace created from here on.

   > ⚠️ The **BestEffort → Burstable** improvement is not retroactive. A LimitRange applies only at pod admission, so the QoS spread is still 35 BestEffort / 33 Burstable and will only shift as pods are recreated. Nothing to do — it converges on its own — but do not read the unchanged count as a failure.

   > This makes Kyverno's background-controller load-bearing, which settles §3.5 in favour of *keeping* Kyverno and using it, rather than stripping three controllers.
3. Bump `kube-apiserver` request to `2Gi` in the Talos machine config (`cluster.apiServer.resources`) — 512 Mi against a steady 2.35 GiB makes the scheduler's arithmetic meaningless. Its size is expected for 161 CRDs and 36 ArgoCD apps; it is not a leak.
4. Popeye **POP-505** already flags two: `longhorn-manager` (759 Mi vs 256 Mi requested, 296%) and `coredns` (208 Mi vs 10 Mi, 2080%).

### 3.3 🟠 Monitoring stack — the largest tunable consumer (2.68 GiB, 457m)

**ClickHouse** (`1 437 Mi`, 237m) — 7-day TTL on every `otel_*` table, ~350 MiB/day ingest, 3.4 GiB of live parts. Retention config is sound.

> 🟡 **`mark_cache_size` and `index_mark_cache_size` are both at the 5 GiB upstream default** while `max_server_memory_usage` is 4.5 GiB (0.9 × the 5 Gi container limit) — 10 GiB of nominal cache inside a 4.5 GiB budget, never scaled to the container.
>
> **Corrected 2026-09-05 — this was first written as High severity ("an OOMKill waiting for a heavy scan"). Measurement does not support that.** The marks for every active part in the database total **12.75 MiB**, and the two caches sit at **107 KiB and 101 KiB**. Neither can approach 5 GiB without roughly 400× the current data, so the oversized default costs nothing today. It is worth fixing because it leaves a cache able to crowd out queries and merges if this ever grows into a real dataset, and because a memory budget that advertises more cache than total RAM cannot be reasoned about — not because anything is at risk now.

> ✅ **Applied 2026-09-05** (`74365b3e`). Both caches now read 512 MiB against the unchanged 4.50 GiB budget. Data intact across the change: 312 active parts, 3.37 GiB, 470M rows, ingest lag ~10s.
>
> **Correction:** this was written as "changeable_without_restart, so the fix reloads in place." That is true of ClickHouse itself but not of the deployment — the clickhouse-operator rolls the StatefulSet whenever the `ClickHouseCluster` spec changes, so applying it cost a pod restart and a short ingest gap. Assume a roll for any future `extraConfig` edit, `changeable_without_restart` notwithstanding.
>
> Do not read the mark cache hit rate (**89.5k hits against 8.1M misses**) as a symptom of the size: parts here are created by ingest and destroyed by TTL merges faster than they are ever re-read, so almost every mark read is for a part never seen before. A larger cache cannot fix that and a smaller one does not cause it.

> ✅ **`system.*` log retention — already solved, this audit was wrong.** The original text claimed `query_log` + `part_log` + `asynchronous_metric_log` (267 MiB) had **no TTL**, inferred from `min(min_time)` reading as epoch in `system.parts`. That inference was invalid — those tables simply do not partition on that column. All four carry `TTL event_date + toIntervalDay(3)` from `clickstack.systemLogs.ttl`, and `metric_log` is removed outright via `"@remove": "1"`. No action needed.

> 🟡 ClickHouse runs as the **`default` ServiceAccount** and emits `Effective user of the process (clickhouse) does not match the owner of the data (root)` on every reconcile — set `fsGroup: 101` / `runAsUser: 101` on the pod template.

**Four collectors are running.** They do not overlap functionally, but it is worth knowing the split:

| Collector | Receivers | Cost | Purpose |
|---|---|---:|---|
| `otel-node-agent` (DS) | `file_log`, `hostmetrics`, `kubeletstats`, `prometheus` | 47m / 106 Mi | node logs + node metrics |
| `otel-cluster` | `k8s_cluster`, `k8sobjects`, `prometheus` | 6m / 59 Mi | cluster-level events/state |
| `clickstack-otel-collector` | `otlp`, `jaeger`, `zipkin`, `prometheus` | 22m / 132 Mi | app OTLP gateway (OpAMP-driven) |
| `obi` (eBPF, DS) | eBPF uprobes | **137m / 674 Mi** | auto-instrumented RED metrics |

> 🟠 **`obi` is the second-most expensive workload in the cluster** (674 MiB, 137m CPU sustained) and is the *only* pod requiring `hostPID` (Kubescape C-0038, the sole cluster-wide failure of that control) on top of `privileged` + `hostNetwork` + writable `hostPath`.
>
> ✅ **Decision 2026-09-05: keep it, risk accepted.** The auto-instrumented RED metrics are wanted, so the privileged posture is an accepted cost rather than an open finding. This closes C-0038 and `obi`'s share of C-0057 / C-0041 / C-0045 / C-0046 as *accepted*, not as fixed — they will keep appearing in every Kubescape run, and that is expected. Its 674 MiB is likewise a deliberate spend. Nothing to action; revisit only if the metrics stop being used.

> 🟡 `clickstack-otel-collector` has restarted 4× in 10 days. Its bootstrap ConfigMap ships a `debug` exporter; the effective pipeline comes from OpAMP (data does reach ClickHouse), but the restarts deserve a look at `memory_limiter` sizing — it has no container limit today.

### 3.4 🟠 Network segmentation

Popeye **POP-1204**: 62 pods with unsecured ingress, 51 with unsecured egress.
Kubescape **C-0030 "Ingress and Egress blocked" — 29% compliance (63/89)** · **C-0260 "Missing network policy" — 72%** · **C-0054 "Cluster internal networking" — 29% (17/24 namespaces)**.

Only 3 namespaces carry NetworkPolicies (`argocd`, `auth`, `longhorn` — all chart-supplied). **Zero `CiliumNetworkPolicy` / `CiliumClusterwideNetworkPolicy` exist**, despite Cilium being the CNI and Hubble being deployed.

Namespaces with **no policy at all**: `kube-system`(22 pods), `monitoring`(18), `vault`(14), `longhorn`*(9)*, `hook`(8), `cert-manager`(8), `external-secrets`(6), `database`(6), `s3`(4), `traefik`, `obi`, `netbird`, `dex`, `vault-operator`, `vault-infra`, `local-path-storage`, `kubelet-serving-cert-approver`, `argocd`*.*

**Actions** — highest value first, since you already pay for Cilium:
1. Start with **`vault` and `monitoring`**: a default-deny `CiliumNetworkPolicy` in `vault` is the single highest-value policy in the cluster (OpenBao + the raft store + the configurer).
2. Add a default-deny + explicit-allow baseline per namespace; put it in `2.argo/app/templates/` so it lands with every new namespace.
3. Popeye **POP-1208**: 5 stale Longhorn NetworkPolicies select pods that never exist here (`backing-image-manager`, `backing-image-data-source`, `share-manager`) — harmless, chart-supplied.

### 3.5 🟠 Kyverno — 428 MiB for one Audit policy *(resolved 2026-09-05: now generates the LimitRanges, see §3.2)*

`hook` namespace runs **4 controllers** (admission 171 Mi, cleanup 115 Mi, reports 74 Mi, background 68 Mi) plus 56 `PolicyReport` objects in etcd, to enforce exactly **one `ClusterPolicy`** — `add-certificates-volume`, in `validationFailureAction: Audit`, `background: false`.

**Actions**
- If Kyverno is intended as the policy engine: **use it**. It could close §3.2 (mutate in default limits), §3.7 (`automountServiceAccountToken: false`), and Pod Security in enforce mode — all findings that currently need per-chart edits. That would make the 428 MiB pay for itself.
- If it exists only for `add-certificates-volume`: that single mutation is achievable with a `trust-manager` bundle + chart values, and you can **drop `background-controller`, `cleanup-controller` and `reports-controller`** (257 MiB + 56 etcd objects) by setting `backgroundController.enabled=false`, `cleanupController.enabled=false`, `reportsController.enabled=false` in `2.argo/helm/hook/main/values.yaml`.

Related: **C-0039 "mutating admission controller" 0% (8/8)** and **C-0036 "validating admission controller" 0% (16/16)** — this is Kubescape flagging *the existence* of 24 webhooks (kyverno, cert-manager, longhorn, external-secrets, vault, authentik, clickhouse, mongodb) as an attack surface. Informational here, but 24 webhooks on a single-node cluster is real availability risk: **every one of them is a single-replica deployment with no `PodDisruptionBudget` and `failurePolicy` likely `Fail`.**

### 3.6 🟡 Dead weight — KubeBlocks / MongoDB-Enterprise leftovers

| Leftover | Location | Cost |
|---|---|---|
| 29 ConfigMaps (`apecloud-mysql-scripts`, `mysql*-config-template`, `mongodb*-config-template`, `postgresql1{2,4,5,6,7,8}-configuration-1.0.2`, `*-custom-metrics`) | `argocd` ns | etcd + 21 of the 21 C-0012 "credentials in config files" findings |
| `Service/operator-webhook` → selector `mongodb-kubernetes-operator`, no pods | `argocd` ns | Popeye **POP-1100 (error)** |
| `Job/zitadel-cleanup` — `Failed`/`DeadlineExceeded` since 2026-06-29 | `zitadel` ns | 67 days stale; `zitadel` ns holds nothing else |
| Images: `apecloud/clickhouse:25.9.7` (783 MB), `percona-server-mongodb:8.0.17` (299 MB), `mongo:7` (280 MB), `clickhouse-server:latest` (263 MB), `clickhouse-server:26.4/25.7-alpine`, `netshoot:latest`, 3 stale `goauthentik/server` tags, 2 stale `longhorn-instance-manager` | node image cache | **~3.5 GB of 36.2 GB** |

**Actions**
1. `kubectl -n argocd delete cm` for the 29 orphans; `kubectl -n argocd delete svc operator-webhook`; `kubectl -n zitadel delete job zitadel-cleanup` and drop the `zitadel` namespace if the migration to `authentik` is complete (it is, per the operator migration).
2. Talos garbage-collects unused images on disk pressure only; at 11% usage that will never fire. Prune manually via `talosctl -n <node> image ls` / `image rm` if you want the 3.5 GB back — low priority given 423 GB free.

> ✅ **DONE 2026-09-05.** Deleted **52 ConfigMaps** (the audit said 29 — the original grep matched only mysql/mongo/postgres/apecloud and missed the `kafka`, `etcd` and `redis` addons), **21 Helm release records** across 7 orphaned `kb-addon-*` releases, and the orphan `argocd/operator-webhook` Service. `argocd` ConfigMaps: 64 → 12. Zero `kb-addon-*` resources remain cluster-wide; ArgoCD healthy with no new restarts. Backup of everything deleted is in the session scratchpad (`kb-backup/`), restorable with `kubectl apply -f`.
>
> ⚠️ **`helm uninstall` cannot remove these** — worth knowing for the next orphaned operator. The release manifests reference `ActionSet`, `BackupPolicyTemplate`, `ComponentDefinition` and `ComponentVersion`, whose CRDs are already gone, so Helm fails to build the delete manifest and aborts — leaving the release stuck in `uninstalling`. The fix is to delete the `sh.helm.release.v1.*` Secrets directly, after confirming which real resources the release still owns (here: only ConfigMaps, all held by `helm.sh/resource-policy: keep`, which is why they outlived the uninstall in the first place).
>
> ✅ **`zitadel` namespace deleted 2026-09-05**, with both stale repo references cleaned up. Namespaces 24 → 23. It held only the failed `zitadel-cleanup` Job, an `openbao-tls` Secret and the trust-manager-distributed `weebo.poc` bundle; no pods, and no ArgoCD Application targeted it, so nothing recreates it. Verified before deleting that cluster OIDC runs through **dex** (`--authentication-config` names issuer `https://dex.weebo.poc`, audience `weebo-kube`), so authentication was never involved. Namespace contents backed up to `kb-backup/zitadel-namespace.yaml`.
>
> **Repo references removed:**
> - `https://charts.zitadel.com` from the `infra` AppProject `sourceRepo` list (`2.argo/app/values.yaml`) — 13 → 12 entries, no Application used it.
> - `task create-kubeconfig-oidc` (`Taskfile.yml`) read a client id from `zitadel/cluster-auth` and wrote it over `args[3]`. **That Secret no longer existed, so the whole task aborted before running a single command** — it had been broken since the move to dex, not by this cleanup. `weebo-kube` is a dex `staticClient` and the template already carries the correct `--oidc-client-id`, so the lookup and its `yq` line are simply gone. Re-ran the task after the change: it now regenerates `kubeconfig.oidc.yaml` correctly with the client id, server and CA intact.
>
> Popeye's POP-307 finding about a Job referencing a non-existent `zitadel` ServiceAccount is resolved by the same deletion.

### 3.7 🟡 Workload security posture

| Kubescape control | Compliance | Notes |
|---|---:|---|
| **C-0013 Non-root containers** | **25%** (57/77) | Popeye POP-302/306 agree: 39 pods + 54 containers may run as root |
| **C-0053 Access container service account** | **33%** (88/133) | |
| **C-0034 Automatic SA token mapping** | **62%** (70/186) | Popeye POP-301: 35 pods mount an unused SA token |
| **C-0017 Immutable container filesystem** | **44%** (43/77) | no `readOnlyRootFilesystem` |
| **C-0016 Allow privilege escalation** | **55%** (34/77) | |
| **C-0055 Linux hardening** | **55%** (34/77) | no seccomp/AppArmor/capability drop |
| **C-0015 List Kubernetes secrets** | **72%** (42/154) | 31 ServiceAccounts can list secrets |

Privileged / host-namespace workloads (all legitimate infrastructure, but worth an explicit accept-decision):

| Control | Workloads |
|---|---|
| **C-0057 privileged** (10) | `cilium`, `cilium-envoy`, `longhorn-{manager,csi-plugin}`, `engine-image-ei-*` ×2, `instance-manager` ×2, **`netbird/exit-node-ingress`**, **`obi`** |
| **C-0041 hostNetwork** (4) | `cilium`, `cilium-envoy`, `cilium-operator`, **`obi`** |
| **C-0038 hostPID** (1) | **`obi`** — the only one |
| **C-0045 writable hostPath** (15) | cilium ×2, `kube-apiserver`, all of longhorn (9), `otel-node-agent`, `obi` |
| **C-0046 insecure capabilities** (4) | `cilium`, `cilium-envoy`, `longhorn-csi-plugin`, **`netbird/exit-node-ingress`** |

**Actions**
1. **Cheapest wins, ordered by findings-closed-per-edit**:
   - `automountServiceAccountToken: false` on the 35 pods that never call the API (Popeye lists them; `traefik`, `dex`, `hubble-ui`, `longhorn-ui`, `argocd-redis`, `clickstack` are all safe) → closes ~70 C-0034/C-0053 findings.
   - `securityContext: {runAsNonRoot: true, seccompProfile: {type: RuntimeDefault}, allowPrivilegeEscalation: false, capabilities: {drop: [ALL]}}` on every non-infra workload → closes C-0013/C-0016/C-0055 for ~34 workloads at once. A Kyverno `mutate` rule does this globally (see §3.5).
2. **10 pods on the `default` ServiceAccount** (POP-300) — `argocd-redis`, `authentik-server`, `clickstack`, `clickstack-clickhouse-0-0-0`, `clickstack-keeper-0-0`, `clickstack-preauth`, `netbird/exit-node-ingress`, and 3 terraform jobs. Give each a dedicated SA (or at minimum set `automountServiceAccountToken: false`).
3. **`netbird/exit-node-ingress` is privileged with insecure capabilities and no probes** — it is an ingress path from outside the cluster. Narrow to `NET_ADMIN` + `NET_RAW` instead of `privileged: true` if the image allows it.
4. **11 workloads on `:latest`** (POP-101). ✅ **Fixed in the repo 2026-09-05** (uncommitted). The 11 findings were only **two distinct images**, and each was invisible to Renovate for a different reason:

   | Image | Where | Was | Now |
   |---|---|---|---|
   | `hashicorp/terraform` | `2.terra/{auth,vault}/job.yaml`, 4 occurrences | `:latest` | `1.16.1` |
   | `clickhouse/clickhouse-keeper` | `2.helm/clickstack/values.yaml` | operator default `:latest` | `25.8-alpine` |

   The keeper had **no `containerTemplate.image` at all**, so the operator fell back to `:latest` while the server directly beside it was pinned to `25.8-alpine` — half the ClickHouse quorum silently floating. It now pins to the server's major.minor, and the two are grouped in Renovate so a bump can never be half-applied again.

   The terraform Jobs are raw manifests applied as ArgoCD PostSync hooks, so neither the `# renovate:` customManager (it only reads `version:` keys in `values.yaml`) nor `helm-values` could see them. Renovate's built-in **`kubernetes` manager ships with no file pattern at all** — plain Kubernetes YAML is too ambiguous to match blind — so it finds nothing until pointed somewhere. Now pointed at `2.terra/**/*.yaml`. `2.terra/**` also joins the majors-need-dashboard-approval rule, since those Jobs run `terraform apply` against live Vault and Authentik state.

   > **Verified by extraction, not by reading the config.** `renovate --platform=local --dry-run=extract` reports `hashicorp/terraform@1.16.1` from both `2.terra/auth/job.yaml` and `2.terra/vault/job.yaml` (2 deps each), and `clickhouse/clickhouse-keeper@25.8-alpine` alongside `clickhouse/clickhouse-server@25.8-alpine` from `2.helm/clickstack/values.yaml`. Zero `:latest` remain anywhere in the repo.
5. **RBAC**: 3 subjects hold wildcard + admin + delete-events rights — `argocd-application-controller` (expected), `longhorn-support-bundle` (**should be scoped or removed — it is a debug SA**), and the `labsso:weebo_admin` group (expected, this is your admin group). `C-0037 CoreDNS poisoning`: 19 subjects can modify CoreDNS.

### 3.8 🟡 Availability & health

**Single points of failure** — every workload runs 1 replica on 1 node, so this section is about *restart behaviour*, not HA:

- **No `HorizontalPodAutoscaler` anywhere**; only 7 PDBs exist, 5 of which report **`ALLOWED DISRUPTIONS: 0`** (`authentik-weebo-authentik`, `csi-attacher`, `csi-provisioner`, `instance-manager` ×2, `vault-webhook`).

  > **Confirmed, not theoretical.** Each of the five was tested against the eviction API with `dryRun=All`; all five returned `Cannot evict pod as it would violate the pod's disruption budget`. Any drain — including the one a Talos upgrade performs — hangs today.

  > ✅ **Fixed in the repo 2026-09-05** (uncommitted). The five split into two unrelated causes:
  >
  > **Two are chart defaults** with `minAvailable: 1` against `replicaCount: 1`, which pins `disruptionsAllowed` at 0 forever — a PDB that protects nothing and blocks everything. Both charts expose `podDisruptionBudget.enabled`, now set to `false`:
  > - `vault-infra/vault-webhook-vault-secrets-webhook` → `2.argo/helm/vault/main/templates/hook/hook.yaml`
  > - `auth/authentik-weebo-authentik` → `2.argo/helm/auth/main/templates/authentik/operator.yaml`
  >
  > **Four are Longhorn's**, created by longhorn-manager at runtime — no owner references, no Helm or ArgoCD labels — so deleting them live just brings them back. The lever is `nodeDrainPolicy`, which this repo had at `block-for-eviction`. On a single node with `defaultReplicaCount: 1` that can never be satisfied: there is no other node to evict replicas to, and this node always holds the last replica, so the three `*last-replica` variants deadlock too. Changed to **`allow-if-replica-is-stopped`**, which keeps the protection worth keeping — Longhorn still refuses to let instance-manager be evicted while a replica is running, so a drain cannot pull the data path out from under an attached volume — while letting the drain finish once workloads are evicted and volumes detach. (`always-allow` also unblocks it but drops that protection for nothing gained.) Valid options, from the setting's own validating webhook: `block-for-eviction`, `block-for-eviction-if-contains-last-replica`, `block-if-contains-last-replica`, `allow-if-replica-is-stopped`, `always-allow`.
  >
  > ⚠️ **One thing to confirm after this syncs.** The two `instance-manager` PDBs are unambiguously governed by `nodeDrainPolicy`. The `csi-attacher` and `csi-provisioner` PDBs are strongly *implied* to be — they carry no labels or owner refs and were created 2026-08-16, six weeks after their Deployments (2026-07-05) and exactly when Longhorn volumes came into use, which is the signature of drain-protection rather than deployment-time creation — but that was inferred, not proven. Re-run the eviction dry-run on all four after the sync; if the two CSI ones still refuse, they need a separate answer (drain with `--disable-eviction`, which issues DELETE instead of eviction and bypasses PDBs entirely).
- **`clickstack-mongodb-arb` StatefulSet is scaled to 0** (Popeye POP-500). ~~Dead resource, delete it.~~ **Correction 2026-09-05: do not delete.** It carries a controller `ownerReference` to the `MongoDBCommunity/clickstack-mongodb` CR — it is the operator's arbiter StatefulSet, held at 0 because the replica set is configured with `members: 1` and no arbiters. Deleting it just makes the operator recreate it. Popeye's POP-500 is a false positive here.
- **Popeye POP-102/103/104: 29 pods with no probes at all**, including `argocd-{applicationset,dex,notifications,redis}`, `external-secrets`, `mongodb-kubernetes-operator`, `longhorn/csi-*` ×4, `longhorn-ui`, `netbird/exit-node-ingress`, `obi`, `clickstack-mongodb`, and every `openbao-configurer` pod. Kubernetes cannot tell a hung process from a healthy one for any of these.
- **Restarts**: `cilium-envoy` 8×, `metrics-server`/`coredns` ×2/`cilium-operator`/`kubelet-serving-cert-approver` 4× (all 63d — consistent with node reboots, not crash loops). `clickstack-otel-collector` **4× in 10 days** is the only one worth investigating.
- **6 completed Job pods retained for up to 71 days** (`openbao-configurer` ×4, `terra-job-*`, `kyverno-migrate-resources`). Set `ttlSecondsAfterFinished: 86400` on the Jobs in `2.argo/helm/vault/sub/` and `2.argo/helm/auth/sub/`.
- **Popeye POP-1106 (error)**: `vault/openbao` Service exposes `TCP:statsd:9102` with no matching container port — dead port, remove it from the service.
- **Popeye POP-307**: 4 Jobs reference non-existent ServiceAccounts (`kyverno-migrate-resources`, `zitadel`). Cleanup, tied to §3.6.
- **50 × POP-1109** "single endpoint associated with this service" — inherent to a single-node cluster, informational.

### 3.9 🟢 ArgoCD / GitOps hygiene

36 applications, all `Healthy`. **3 `OutOfSync`**: `authentik-operator` (0.11.0), `main-storage` (develop), `monitoring` (develop) — worth reconciling before they drift further, since `monitoring` is exactly where §3.3's fixes will land.

`argocd-server` runs with **`server.insecure: true`** and `server.dex.server.strict.tls: false` / `server.repo.server.strict.tls: false`. That is the standard "TLS terminates at Traefik" pattern and is fine given the ingress, but it means **anything inside the cluster can reach the ArgoCD API in plaintext** — and there is no NetworkPolicy on the `argocd` namespace's ingress from other namespaces (§3.4). Fix the network policy or turn TLS back on.

`argocd-application-controller` has **no liveness probe** and **no resource limits** while sitting at 750 MiB — it is the single component whose failure stops all reconciliation.

---

## 4. Prioritised action plan

### Do this week

| # | Action | Effort | Closes |
|---|---|---|---|
| 1 | ~~Filesystem-trim + `remove-snapshots-during-filesystem-trim` + weekly RecurringJob~~ | ✅ **DONE** | 🔴 §3.1 — **13.25 GB reclaimed**, write-stall risk gone |
| 2 | ~~Cap `mark_cache_size` + `index_mark_cache_size` at 512 MiB~~ | ✅ **LIVE** `74365b3e` | 🟡 §3.3 — both now 512 MiB; cost one operator-driven pod roll |
| 3 | ~~Kyverno-generated `LimitRange`~~ (2Gi limit / 64Mi request) | ✅ **LIVE** `74365b3e` | 🔴 §3.2 — 19 namespaces generated, `kube-*`/`longhorn` skipped, order-independent |
| 4 | ~~Drop the 5 zero-disruption PDBs~~ — 2 chart PDBs disabled, Longhorn `nodeDrainPolicy` → `allow-if-replica-is-stopped` | ✅ **IN REPO** (uncommitted) | 🟡 §3.8 — unblocks the next Talos upgrade; verify CSI PDBs after sync |
| 5 | ~~Delete the KubeBlocks leftovers~~ (52 CMs, 21 Helm releases, `operator-webhook` svc, `zitadel` ns) | ✅ **DONE** | 🟡 §3.6 — 21 C-0012 findings + POP-307 |

### Do this month

| # | Action | Effort | Closes |
|---|---|---|---|
| 6 | ~~Decide on `obi`~~ — **settled: keep it, risk accepted in writing** (§3.3). 674 MiB and the privileged/hostPID posture are a deliberate spend | ✅ **DECIDED** | 🟠 C-0038/C-0057/C-0041/C-0045/C-0046 accepted, not fixed |
| 7 | ~~Decide on Kyverno~~ — **settled: keep it.** Item 3 makes the background-controller load-bearing. Remaining work is to extend it to §3.7 (`automountServiceAccountToken`, `securityContext`) rather than 40 chart edits | 2 h | 🟠 §3.5 — Kyverno now earns its 428 MiB |
| 8 | **Explicit requests/limits** on the 12 top consumers (table in §3.2) + apiserver request → 2Gi in Talos config | 3 h | 🔴 §3.2 |
| 9 | **Default-deny `CiliumNetworkPolicy`** starting with `vault`, then `monitoring`, then the rest | 1 day | 🟠 §3.4 — C-0030/C-0054/C-0260 |
| 10 | **`automountServiceAccountToken: false`** on the 35 pods that never call the API | 2 h | 🟡 §3.7 — ~70 findings |
| 11 | ~~Pin the 11 `:latest` tags~~ + put both images under Renovate | ✅ **IN REPO** (uncommitted) | 🟡 §3.7 — zero `:latest` left in the repo |
| 12 | ~~Add TTLs to `system.query_log`/`part_log`/`asynchronous_metric_log`~~ — **already done, audit was wrong (see §3.3)**; add `ttlSecondsAfterFinished` to the terraform Jobs | 20 min | 🟡 §3.8 |

### Backlog

- Probes for the 29 pods that have none — prioritise `argocd-application-controller` (liveness) and `external-secrets`.
- `securityContext` hardening pass (C-0013/C-0016/C-0017/C-0055) — best done as a Kyverno mutate rule rather than 40 chart edits.
- Scope or remove the `longhorn-support-bundle` ServiceAccount's wildcard ClusterRole.
- Remove the dead `statsd:9102` port from the `openbao` Service.
- Prune the ~3.5 GB of stale images from the node (cosmetic at 11% disk usage).

---

## 5. What is already good

- **7-day TTL on every telemetry table** with `ttl_only_drop_parts = 1` — retention is correctly designed, and ingest (~350 MiB/day) is comfortably inside the volume.
- **All 11 cert-manager Certificates are `Ready`** with healthy renewal windows; the earliest expiry is 2026-09-24 with renewal on 2026-09-14.
- **Zero memory pressure** (PSI avg300 = 0), zero warning events beyond two cosmetic ClickHouse notices, no crash loops.
- **36/36 ArgoCD applications `Healthy`**, 33 of them `Synced` — the GitOps layer is doing its job.
- **Secrets are externalised** — `external-secrets` + OpenBao + `vault-secrets-webhook`; Popeye's secret scanner found **zero** issues (score 100).
- **RBAC is tight where it counts** — only 3 wildcard subjects, all explainable; `clusterroles` scored 100.
- Popeye scored **100** on namespaces, nodes, PVs, PVCs, PDBs, replicasets, roles, rolebindings, serviceaccounts, secrets, ciliumendpoints and cnpg clusters.

---

## Appendix — raw reports

```
popeye.json      /tmp/popeye/weebo4-cluster/admin@weebo4-cluster/…-popeye.json
kubescape.json   15 MB, 768 resources, 804 failed control-resource pairs
```

Reproduce with `task secscan` (writes `kubescape.html` + `popeye.html` to the repo root).
