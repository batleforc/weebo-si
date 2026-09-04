# Moving Authentik from Terraform to the weebo-authentik operator

`2.terra/auth` and the operator can both point at the same Authentik instance
without fighting, so this is done one object at a time, with a working system
after every step. Nothing here ever recreates an Authentik object.

Two files hold the whole migration:

- `2.argo/helm/auth/sub/values.yaml` — the CRs, one `enabled` flag each.
- `2.terra/auth/migration/` — the one-shot jobs that make Terraform _forget_
  what the operator has taken over.

Everything below assumes the repo's kubectl wrapper, `task k -- <args>`
(`Taskfile.yml`, `KUBECONFIG=0.config/kubeconfig.yaml`). Plain `kubectl` works
too if your KUBECONFIG is already pointed at the cluster. `auth.weebo.poc`,
`vault.weebo.poc` and friends resolve only over the VPN (`task vpn:`), which is
why every live check below is written to run **from inside the cluster** —
those work from anywhere.

**Requires operator 0.10.0.** Six changes are load-bearing and none of them
exists in 0.6.0:

- **`AuthentikFlow`**, cluster-scoped and slug-keyed (0.7.0). `flow.tf`'s
  `token-authentik-flow` was the one Terraform `resource` with no CRD; it now
  has one. New phase 2b.
- **`AuthentikApplication.spec.secretTargets`** (0.7.0) — a per-application
  list of Vault paths / Kubernetes Secrets the oauth2 credentials are fanned
  out to, each Vault entry pinning an exact path. This is what turns phase 4
  from "pick one of three bad options" into a normal phase; section 3 is
  written around it.
- **`AuthentikInstance.spec.secretStore.vault.caSecretRef`** (0.8.0) — the CA
  the operator verifies **Vault's** TLS with, read from a Kubernetes Secret
  over the API rather than from a mounted file. This is the whole of
  prerequisite 2 in 3.2; without it there is no supported way to make the
  operator trust openbao.
- **`AUTHENTIK_URL` is the per-application issuer** (0.8.0). It used to be
  the gateway's REST `base_path`. `upsert_oauth2_provider` now takes the
  application's slug and the gateway carries a `web_base_url` separate from
  the API base, so the credential written out is
  `<spec.url>/application/o/<slug>/` — character for character what
  `harbor.tf`/`s3.tf`/`argo.tf`/`che-cluster.tf` interpolate today. Section
  3.3 used to be a list of consumers to patch around this; it is now a no-op.
- **`spec.url` is split into a REST base and a web base** (0.9.0). The bullet
  above only holds if the operator can reach the API at all, and in 0.8.0 it
  cannot: `gateway_factory.rs` handed `spec.url` to the generated client
  verbatim, while that client appends every path to a base that has to end in
  `/api/v3` (its own default `base_path` is literally `/api/v3`). So
  `url: https://auth.weebo.poc` 404s on every call, and "fixing" it by writing
  `https://auth.weebo.poc/api/v3` feeds the same string to the issuer above
  and writes `.../api/v3/application/o/<slug>/` into all five Vault paths.
  `api::instance::split_urls` now derives both from the web base (and trims a
  stray `/api/v3` rather than honouring it). The same function backs the
  importer's `--authentik-url`.
- **`AuthentikInstance.spec.tls.caSecretRef`** (0.10.0) — the same trick as
  `secretStore.vault.caSecretRef`, but for the **Authentik** API. Not optional
  here: `auth.weebo.poc` is signed by the weebo private PKI and the operator
  image is `distroless/cc`, which ships the public roots only. See phase 0.

  0.7.0 also gives `oauth2.signingKey` a default of
  `"authentik Self-signed Certificate"` — the same certificate
  `data.authentik_certificate_key_pair.generated` resolves in `data.tf`, so
  every provider here is unaffected. Note the shift though: in 0.6.0 an omitted
  `signingKey` sent no key at all and adoption preserved whatever was live;
  since 0.7.0 an omitted `signingKey` _sets_ the self-signed cert. Every CR in
  `sub/values.yaml` names it explicitly for that reason. An explicit `null`
  still means "no signing key".

---

## 0. Where this migration stands

Verified against the live cluster on **2026-09-04**. Re-run the commands in
"how it was checked" before trusting this table — it is a snapshot, not state.

| Phase                      | Operator side                                                                                           | Terraform side                                                                                                                   | Verdict                                                            |
| -------------------------- | ------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------ |
| **0** foundation           | `AuthentikInstance/main` Ready, `AuthentikNamespacePolicy/weebo-allow` accepted, `tls.caSecretRef` live | nothing to do                                                                                                                    | **done**                                                           |
| **1** identity             | 3 `AuthentikGroup` + 1 `AuthentikUser`, all Ready with `authentikId`                                    | `state rm` ran 2026-09-01 22:55; `group.tf` downgraded to `data`; `user.tf` gone from disk and from `kustomization.yaml`         | **done**                                                           |
| **2a** brand               | `AuthentikBrand/weebo` Ready, id `e16f5533-…`, `flow_device_code` preserved                             | **not done** — `authentik_brand.default` is still in state, and the block is _already deleted_ from the working tree's `flow.tf` | **half — hazard, see below**                                       |
| **2b** device-code flow    | no CR; `flows.deviceCode.enabled: true` is set in the working tree only                                 | `authentik_flow.token-authentik-flow` still in state and still in `flow.tf`                                                      | not started                                                        |
| **3** longhorn, clickstack | flags `false`                                                                                           | in state                                                                                                                         | not started                                                        |
| **4** harbor…vault         | flags `false`; `foundation.vault.enabled: false`                                                        | in state                                                                                                                         | not started — but **both 3.2 prerequisites are already satisfied** |

Supporting facts, all verified:

- Operator image is `ghcr.io/batleforc/weebo-authentik-operator:v0.10.0`, 9
  CRDs present, `caSecretRef` and `secretTargets` both in the served schemas.
- The `authentik-operator` ArgoCD Application reports **OutOfSync on all 9
  CRDs** while `operationState` says `Succeeded`. This is the usual ArgoCD
  large-CRD diff, not a failed rollout — the fields the migration needs are
  live (checked directly, see phase 0). Do not "fix" it by re-syncing mid-phase.
- The `terra-authentik` Application has auto-sync **suspended** — but by a live
  patch (`spec.syncPolicy.automated.enabled: false`), and that field is **not
  in git**: `main/templates/authentik/terra-config.yaml` renders
  `automated: {prune: true, selfHeal: true}` with no `enabled`. It survives
  today only because ArgoCD does not currently diff it. Treat the suspension as
  a sticky note, not as a lock.
- Live Authentik holds 7 applications (`argo`, `che-cluster`, `clickstack`,
  `harbor`, `longhorn`, `s3`, `vault`), 7 oauth2 providers and 2 proxy
  providers. `clickstack` is still `mode=forward_single`.

### The hazard that was here — resolved 2026-09-04

`flow.tf` had already lost its `authentik_brand.default` block while
`terraform state` still held the resource. The PostSync job does
`rm -rf *.tf; cp /scripts/*.tf .; terraform apply`, so committing that edit
would have planned a **real delete** of the live brand.

Resolved by running `PHASE=brand` *before* the commit, then pushing, then
syncing: the apply came back `0 added, 6 changed, 0 destroyed` and the brand
count stayed at 2. The general rule it illustrates is worth keeping:

> Between a `state rm` and the matching `.tf` edit reaching the PVC, config and
> state disagree in the *opposite* direction — config declares a resource state
> no longer has, so a plan in that window wants to **create a duplicate**. The
> suspension in section 4 is what protects that window, and it is the reason
> not to resume the loop until the push has landed and synced.

### How the table was checked

```bash
# operator version + CRDs + the two schema fields the migration needs
task k -- -n auth get deploy -o custom-columns=NAME:.metadata.name,IMAGE:.spec.template.spec.containers[*].image
task k -- get crd | grep authentik.weebo.io | wc -l                      # 9
task k -- get crd authentikinstances.authentik.weebo.io -o yaml | grep -c caSecretRef
task k -- get crd authentikapplications.authentik.weebo.io -o yaml | grep -c secretTargets

# every CR the operator owns, with its adopted id and readiness
task k -- get authentikgroups,authentikusers,authentikbrands,authentikflows,\
authentikapplications,authentikaccesspolicies,authentikoutposts,\
authentikinstances,authentiknamespacepolicies -A \
  -o custom-columns='KIND:.kind,NAME:.metadata.name,ID:.status.authentikId,READY:.status.conditions[?(@.type=="Ready")].status'

# what Terraform still believes it owns, and which phases have already run
task k -- -n auth logs job/terra-state-rm | tail -60
task k -- -n auth get app 2>/dev/null; task k -- -n argocd get app \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status,AUTO:.spec.syncPolicy.automated'
```

The authoritative answer to "has phase X's `state rm` run" is on the PVC: each
run drops a `state-backup-<phase>-<timestamp>.tfstate` next to
`terraform.tfstate` and never removes it. List them (read-only, no mutation):

```bash
task k -- -n auth run tfstate-peek --rm -i --restart=Never --image=busybox \
  --overrides='{"spec":{"containers":[{"name":"p","image":"busybox","command":["ls","-la","/terraform"],"volumeMounts":[{"mountPath":"/terraform","name":"v"}]}],"volumes":[{"name":"v","persistentVolumeClaim":{"claimName":"terra-job-authentik"}}]}}'
```

Today that lists exactly one: `state-backup-identity-20260901-225507.tfstate`.
Phase 1 is the only `state rm` that has ever run.

### The plan baseline — "no changes" is not achievable

Every phase below ends with "the plan must be clean". It cannot be, and never
was. Before phase 3 the plan on an untouched module was:

```
Plan: 0 to add, 6 to change, 0 to destroy.
```

**Since phase 3 removed `authentik_provider_proxy.clickstack` from state, the
baseline is 5, not 6.** It drops again with each phase-4 app, and reaches 0
only when `vault` is the last oauth2 provider left. Always compare against the
count for where you are, not against 6.

Those churners are a permanent round-trip failure in the `goauthentik/authentik`
provider (2026.5.0), not migration drift:

- **the five oauth2 providers** (`argo`, `che`, `harbor`, `s3`, `vault`) —
  the provider writes `redirect_uri_type` into every `allowed_redirect_uris`
  entry in state, the API never returns it, so every plan proposes rewriting
  the whole list. `vault` additionally shows its four URIs as six, because the
  list is rebuilt from two overlapping `dynamic` blocks.
- **`authentik_provider_proxy.clickstack`** — `clickstack.tf` deliberately
  omits `internal_host`, so Terraform wants `null`; Authentik ignores the null
  and keeps the stored `http://clickstack-preauth.monitoring.svc.cluster.local:8080`.
  The apply "succeeds" and the next plan proposes it again.

So the real acceptance criterion for every phase is:

> **`0 to destroy`, and nothing in the plan beyond the known churners still in
> state.**

A destroy, or an unexpected resource, is a stop.

### Running a plan without applying anything

There is no `terraform plan` step in the PostSync job, so run one by hand. This
is read-only — it reads the PVC's state and the live APIs and writes nothing:

```bash
cat > /tmp/plan-job.yaml <<'EOF'
apiVersion: batch/v1
kind: Job
metadata:
  name: terra-plan-check
  namespace: auth
spec:
  backoffLimit: 0
  template:
    metadata:
      annotations:
        vault.security.banzaicloud.io/vault-addr: "https://openbao.vault:8200"
        vault.security.banzaicloud.io/vault-role: "auth"
        vault.security.banzaicloud.io/vault-path: "kubernetes"
        vault.security.banzaicloud.io/vault-tls-secret: "openbao-tls"
    spec:
      serviceAccountName: "authentik"
      restartPolicy: Never
      containers:
        - name: terraform
          image: hashicorp/terraform:latest
          command:
            - /bin/sh
            - "-c"
            - |
              set -eu
              cd /terraform
              terraform init -input=false >/dev/null
              terraform plan -input=false -lock=false -no-color
          env:
            - name: TF_VAR_authentik_url
              value: "https://auth.weebo.poc"
            - name: TF_VAR_authentik_token
              value: "vault:mv/data/main-config#AUTHENTIK_BOOTSTRAP_TOKEN"
            - name: TF_VAR_vault_addr
              value: "https://openbao.vault:8200"
          volumeMounts:
            - { mountPath: /terraform, name: terra-job }
            - { mountPath: /etc/ssl/vault, name: openbao-tls }
            - { mountPath: /etc/ssl/certs, name: etc-ssl-certs }
      volumes:
        - name: terra-job
          persistentVolumeClaim: { claimName: "terra-job-authentik" }
        - name: openbao-tls
          secret: { secretName: "openbao-tls" }
        - name: etc-ssl-certs
          secret: { secretName: "weebo.poc" }
EOF
task k -- -n auth delete job terra-plan-check --ignore-not-found
task k -- apply -f /tmp/plan-job.yaml
task k -- -n auth wait --for=condition=complete job/terra-plan-check --timeout=180s
task k -- -n auth logs job/terra-plan-check | grep -E '^  # |^Plan:'
task k -- -n auth delete job terra-plan-check
```

Two things this plan does **not** tell you, both because the PVC's `.tf` files
are whatever ArgoCD last wrote from git:

- it plans against the **committed** `.tf`, not your working tree;
- it will not show the brand destroy described above until that edit is pushed.

That is the point of running `state rm` before committing, not after.

---

## 1. The mechanism that makes this safe

**Adoption happens through `status.authentikId`, never by name.** A CR takes
over an existing Authentik object only if its status already carries that
object's primary key. Apply a CR without it and the operator tries
create-first, collides, reports `AuthentikObjectAlreadyExists`, and stops —
annoying, not destructive. So every phase is: import the id → apply the CR →
patch the id onto its status.

**`kubectl apply` drops `status`.** That is why the patch is a separate step,
and why it cannot be done from git — ArgoCD strips status too. Patching status
out of band is safe: ArgoCD does not diff it, so self-heal will not undo it.

**Fields the CRDs do not model are preserved, not reset.** The operator
updates via `PATCH`, and the generated Authentik client marks every optional
field `skip_serializing_if = "Option::is_none"`. A field the CRD cannot
express is therefore absent from the request body, and Authentik keeps what it
has. Verified for the ones that matter here:

| Live field                         | Set by                       | Survives adoption                     |
| ---------------------------------- | ---------------------------- | ------------------------------------- |
| `client_secret` (all oauth2)       | Authentik                    | yes — never rotated by the operator   |
| `mode = forward_single`            | `clickstack.tf`              | yes                                   |
| `sub_mode = user_username`         | `che-cluster.tf`             | yes                                   |
| `access_token_validity = hours=10` | `che-cluster.tf`             | yes                                   |
| `meta_launch_url`                  | `che-cluster.tf`, `vault.tf` | yes                                   |
| `flow_device_code` on the brand    | `flow.tf`                    | yes — **confirmed live in 2a**        |
| `default_application` on the brand | `flow.tf`                    | yes (currently `null` on both brands) |

The catch is that "preserved" also means "no longer described anywhere in
git". Those values become invisible state on the live instance. Treat the
table above as a list of things to re-check after any operator upgrade that
starts modeling one of them.

0.7.0 was exactly such an upgrade, and it took one field off this table:
`signing_key` is now modeled _and defaulted_, so an omitted `signingKey` no
longer means "leave it alone" — it means "set the self-signed cert". The value
happens to match on every provider here
(`9c470150-b16e-4d75-be74-0e2f3dceeec9`, the self-signed cert, on all five
oauth2 providers; `null` on the two proxy ones), but the rule changed.
`client_secret` is still never rotated; what 0.7.0 adds is that the operator
now _writes_ it somewhere (section 3), where before it only read it back.

---

## 2. What cannot move

Leave these in Terraform. There is no CRD for them:

- Every `vault_*` resource in `vault.tf`: the OIDC auth backend, its two roles,
  and the two identity-group aliases. These are the reason the `vault`
  application migrates last or never.
- The `data` lookups in `data.tf` — flows, property mappings and the
  self-signed certificate are referenced by slug/name and never created by
  either side. `AuthentikFlow` does not change this: adopting a _built-in_ flow
  buys nothing and hands the operator a finalizer on an object Authentik ships.

Two entries left this list in 0.7.0:

- `authentik_flow.token-authentik-flow` (`flow.tf`) now has an `AuthentikFlow`
  CRD — see phase 2b. The CRD models the flow object only, not its stage
  bindings or policies; the live flow has `stages: []` and `policies: []`
  (verified), so it is parity.
- `vault_kv_secret_v2` for the five oauth2 apps is no longer stuck in
  Terraform: `secretTargets` lets the operator write those exact paths. See
  section 3.

**`group.tf` is the third case, and it is neither.** The three groups moved to
CRs in phase 1, but the file did not disappear — it was _downgraded_ from
`resource` to `data`, because eleven references across seven `.tf` files read
`authentik_group.*.id` / `.name`, `vault.tf` among them. That downgrade is
already in place. Any future phase that removes a resource other code
references takes the same shape: swap to `data`, never delete.

---

## 3. The oauth2 credentials — read before phase 4

Five oauth2 applications feed a `vault_kv_secret_v2` with their
`client_secret`:

| App         | Vault path            | Who reads `AUTHENTIK_URL` from it                                  |
| ----------- | --------------------- | ------------------------------------------------------------------ |
| harbor      | `mv/registry/auth`    | nobody in this repo (harbor's OIDC is configured in its own UI)    |
| s3          | `mv/s3/auth`          | nobody in this repo (rustfs OIDC, same)                            |
| argo        | `mv/argocd/auth`      | `main/templates/authentik/auth-secret.yaml` → argocd's OIDC issuer |
| che-cluster | `mv/eclipse-che/auth` | `1.pulu-init/Taskfile.yaml` → `OIDC_ISSUER_URL`                    |
| che-cluster | `mv/dex/auth`         | `main/templates/dex/dex.yaml` → the weebo connector's `issuer`     |
| vault       | _(none)_              | `vault.tf` consumes client_id/secret directly, in Terraform        |

**Terraform cannot read a client secret back** once it stops managing the
provider — the authentik provider ships no `authentik_provider_oauth2` data
source, only `provider_oauth2_config` (the well-known document). That has not
changed. What changed is that the credential no longer needs to round-trip
through Terraform at all.

### 3.1 What `secretTargets` does

`AuthentikApplication.spec.secretTargets` is a list of destinations the oauth2
credentials are written to. An empty list (the default) means "the one
destination the `AuthentikInstance` defines". A non-empty list **replaces**
that: the credentials go to every listed target and nowhere else. Kubernetes
and Vault targets mix freely, and each Vault target may pin an exact KV path
under the instance's mount — which is exactly the shape needed here:

```yaml
secretTargets:
  - backend: vault
    path: eclipse-che/auth # relative to the instance's mount (mv)
  - backend: vault
    path: dex/auth
```

That one CR reproduces both of `che-cluster.tf`'s `vault_kv_secret_v2`
resources. Every app's targets are already written out in `sub/values.yaml`.
The keys written are `AUTHENTIK_CLIENT_ID` / `AUTHENTIK_CLIENT_SECRET` /
`AUTHENTIK_URL` — the same three Terraform writes, and the same three the KV
entries hold today, so nothing is dropped. (A Vault write is a full KV v2
`set`: it replaces the whole document, not a merge. Harmless here because
those three keys are the whole document; check before adding a target to a
path that holds anything else.)

### 3.2 Two prerequisites — both already satisfied

The instance's default `backend` stays `kubernetes` — nothing should land at
`mv/weebo-authentik/auth/<crName>`. But a Vault _target_ reuses the instance's
`secretStore.vault` block for address/mount/auth, and the operator errors the
reconcile if that block is missing. So `foundation.vault.enabled` must be on
before the first phase-4 app, and two things must be true first. **Both were
verified on 2026-09-04** — re-check, do not assume.

1. **The operator's ServiceAccount must be bound to the `auth` Vault role.**
   That role (`mv_policy`, full CRUD on `mv/*`) bound
   `bound_service_account_names = ["authentik", "default"]` in namespace `auth`
   — and the operator runs as `authentik-weebo-authentik`, which was in
   neither. Fixed in `2.terra/vault/terra-map/auth-base.tf`:

   ```hcl
   resource "vault_kubernetes_auth_backend_role" "auth-write" {
     role_name                        = "auth"
     bound_service_account_names      = ["authentik", "default", "authentik-weebo-authentik"]
     ...
   ```

   Do not instead point the operator chart at the existing `authentik` SA: the
   authentik server chart already owns that name in this namespace. The
   `terra-vault` job has applied this — check the **live** role, not the `.tf`
   (this reads the root token out of the cluster; no VPN needed):

   ```bash
   TOKEN=$(task k -- -n vault get secret openbao-unseal-keys \
     -o jsonpath='{.data.vault-root}' | base64 -d)
   task k -- -n vault exec openbao-0 -c vault -- sh -c \
     "VAULT_TOKEN=$TOKEN VAULT_ADDR=https://127.0.0.1:8200 VAULT_SKIP_VERIFY=true \
      bao read auth/kubernetes/role/auth"
   ```

   ✅ Live today: `bound_service_account_names [default authentik-weebo-authentik authentik]`,
   `bound_service_account_namespaces [auth]`, `token_policies [mv_policy]`.
   Note the container is `-c vault`, not `-c bao`.

2. **The operator must trust openbao's self-signed CA** — `caSecretRef`,
   already set in `sub/values.yaml`. Unlike ESO's `SecretStore`,
   `spec.secretStore.vault` has no `caProvider`, and `spec.tls.insecureSkipVerify`
   covers the _Authentik_ API, not Vault. 0.8.0 added the field that closes
   this:

   ```yaml
   caSecretRef:
     name: openbao-tls
     namespace: auth
     key: ca.crt
   ```

   ✅ Live today: `task k -- -n auth get secret openbao-tls -o jsonpath='{.data.ca\.crt}' | wc -c`
   returns 1668.

   The operator `GET`s that Secret through the Kubernetes API and hands the
   PEM to its Vault client — no volume, which matters because the operator
   chart exposes `podAnnotations` and `extraEnv` but **no `extraVolumes`**, so
   there is no file for a `$VAULT_CACERT` to point at.

   Do not reach for `inject-certs: "enabled"` here. That Kyverno policy
   (`2.argo/helm/hook/sub/templates/mount-cert.yaml`) mounts the `weebo.poc`
   trust bundle over `/etc/ssl/certs`, and that bundle is the public roots
   plus the PKI chain from `mv/cert-manager/config` — neither of which signs
   `openbao-tls`. It is what lets a pod trust `https://auth.weebo.poc`; it
   does nothing for `https://openbao.vault:8200`. The pods that do reach Vault
   get its CA from the bank-vaults webhook mounting `openbao-tls` itself, and
   that webhook only mutates a container that already carries a `vault:`-
   prefixed env var — the operator has none.

   `openbao-tls` exists in `auth` because the Vault CR sets
   `caNamespaces: ["*"]`; `key: ca.crt` is the same one the namespace's ESO
   `SecretStore` already verifies Vault with. A configured-but-unreadable CA
   is a hard reconcile error, never a silent fall-back to the system roots —
   which is the behaviour you want, but it means a typo here surfaces as a
   failed application reconcile, not as a warning.

### 3.3 `AUTHENTIK_URL` — closed in 0.8.0, and now the invariant

This used to be the one gap adoption could not close: the operator wrote the
instance's **base** URL where Terraform writes the **per-application issuer**,
so every adoption rewrote the key into a different shape and two in-repo
consumers had to be patched around it.

0.8.0 writes `<spec.url>/application/o/<slug>/`. With the live instance's
`spec.url` = `https://auth.weebo.poc` (verified) and the CR slugs in
`sub/values.yaml` matching the live applications — `harbor`, `s3`, `argo`,
`che-cluster`, `vault`, all confirmed against
`/api/v3/core/applications/?superuser_full_list=true` — the value is
byte-identical to Terraform's.

> Note the asymmetry that makes this worth re-checking per app: the CR key is
> `che`, the slug is `che-cluster`. The **slug** is what the issuer is built
> from. A CR named after the app but slugged wrong points every consumer at an
> issuer that does not exist, and nothing errors.

**So the phase-4 KV diff must be empty.** Not "empty except `AUTHENTIK_URL`" —
empty. A diff on _any_ of the three keys means something is wrong (a slug
mismatch, a rotated secret, an instance `url` with a trailing path) and is a
stop-and-investigate, not an expected shape change.

The consumers therefore need no changes, and every one of them should read the
key rather than keep its own copy of the issuer:

| Consumer                                    | Reads                                                        | State                                                       |
| ------------------------------------------- | ------------------------------------------------------------ | ----------------------------------------------------------- |
| `main/templates/authentik/auth-secret.yaml` | `mv/argocd/auth#AUTHENTIK_URL` → argocd's OIDC issuer        | already did                                                 |
| `1.pulu-init/Taskfile.yaml`                 | `mv/eclipse-che/auth#AUTHENTIK_URL` → `OIDC_ISSUER_URL`      | already did                                                 |
| `main/templates/dex/dex.yaml`               | `mv/dex/auth#AUTHENTIK_URL` → the weebo connector's `issuer` | switched to it; used to hardcode `dex.mainConnector.issuer` |
| harbor, s3                                  | —                                                            | configured in their own UIs, out of this repo               |

`vault.tf` is the deliberate exception: it builds `oidc_discovery_url` from
`authentik_application.vault.slug` in Terraform, and the `vault` application
never leaves Terraform anyway — see the closing paragraph of this section.

The migration order stays **`harbor` → `s3` → `argo` → `che` → `vault`**, but
for a smaller reason than before: harbor and s3 have no in-repo consumer of
their credentials at all, so they prove the Vault plumbing from 3.2 — the role
binding, the CA, the `secretTargets` path — before anything load-bearing
depends on it.

`vault` stays last or never regardless: `vault.tf` derives an entire OIDC auth
backend, two roles and two identity-group aliases from the provider's client id
and secret, and none of those have a CRD equivalent. Its CR ships
`secretTargets: []` — there is no `vault_kv_secret_v2` to take over.

---

## 4. Standing rules

- **Never `terraform destroy`** against this module while the migration is in
  flight, and never delete a resource block whose object is still in state:
  the PostSync job does `rm -rf *.tf; cp /scripts/*.tf .; terraform apply`, so
  a resource dropped from `kustomization.yaml` — or from a `.tf` file — before
  its `state rm` is a resource Terraform plans to **delete for real**.
  `state rm` always comes first. **This is currently violated for the brand;
  see section 0.**
- **Never `kubectl delete` an adopted CR** unless you mean it. They carry
  finalizers: deleting the CR deletes the Authentik object behind it. This is
  also why `auth-app`'s sync policy sets `prune: false` — removing a CR from
  git must not be enough to destroy a provider.
- **Suspend the Terraform apply loop** for the duration of each phase, so the
  PostSync hook cannot race the state edit. On ArgoCD 3.x (this cluster runs
  v3.4.3) use the `enabled` flag rather than nulling the block — it is what the
  UI's "Disable Auto-Sync" writes, and it survives a parent-app self-heal that
  nulling does not:

  ```bash
  # suspend
  task k -- -n argocd patch app terra-authentik --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"enabled":false}}}}'
  # confirm
  task k -- -n argocd get app terra-authentik \
    -o jsonpath='{.spec.syncPolicy.automated}{"\n"}'
  # resume, once the phase's plan meets the section-0 baseline
  task k -- -n argocd patch app terra-authentik --type merge \
    -p '{"spec":{"syncPolicy":{"automated":{"enabled":true,"prune":true,"selfHeal":true}}}}'
  ```

  It is **already suspended** today. Neither form is in git, so both are
  patches that a `kubectl apply` of the rendered Application would drop. Check
  the live value at the start of every phase.

- **Nothing takes effect until it is pushed.** `auth`, `auth-app` and
  `terra-authentik` all track the `develop` branch on the remote, not the
  working tree. Flipping a flag in `main/values.yaml` and syncing does nothing
  until the commit is pushed — and conversely, a `.tf` edit becomes live the
  moment it is pushed _and_ the loop is resumed.

---

## 5. The phases

Each phase is the same six moves:

1. **Suspend** the Terraform loop and confirm it is suspended.
2. **Import** the live object's id with the importer.
3. **Diff** the importer's output against `sub/values.yaml` and fix
   `sub/values.yaml` — the importer wins.
4. **Enable** the flag in `main/values.yaml`, commit, push, sync `auth-app`.
5. **Patch** `status.authentikId` onto each CR (apply drops status) and verify
   the CR reports Ready.
6. **Hand over**: run `state rm` for the phase, edit the `.tf`, push, run a
   plan, resume the loop.

Only the objects change.

### The ids each kind adopts — and why the importer is optional

`status.authentikId` is a string, and which string depends on the kind. Read
straight out of the importer's source (`crates/importer/src/*.rs`), which is
the same value the operator's gateway looks the object up by:

| Kind                     | `status.authentikId` is          | Source                        |
| ------------------------ | -------------------------------- | ----------------------------- |
| `AuthentikGroup`         | the group's pk (uuid)            | `groups.rs`                   |
| `AuthentikUser`          | the user's pk (**integer**)      | `users.rs`                    |
| `AuthentikBrand`         | `brand_uuid`                     | `brands.rs`                   |
| `AuthentikFlow`          | the **slug**                     | `flows.rs`                    |
| `AuthentikApplication`   | the application's **slug**       | `applications.rs`             |
| `AuthentikAccessPolicy`  | the policy binding's pk (uuid)   | `applications.rs`             |
| `AuthentikOutpost`       | the outpost's pk (uuid)          | `outposts.rs`                 |

**`AuthentikApplication` stores only the application's id, never the
provider's.** `reconcile_application` reads the current provider FK back off
the live application (`get_application` → `RemoteApplication.provider_id`) and
PATCHes that provider in place. So adopting an application adopts its provider
too, with nothing extra to patch — and a `spec.provider.kind` that disagrees
with the live provider is *refused* rather than attempted, unless the CR
carries `authentik.weebo.io/allow-disruptive-update: "true"`.

That makes the importer **optional for the rest of this migration**: every id
still needed is a slug you already know, or one query away. The importer needs
the VPN (it runs from your machine against `auth.weebo.poc`); the API queries
below do not, because they go to the ClusterIP service. Helper:

```bash
# ak.sh <api-path> -- query the Authentik API from inside the cluster.
P="${1:?}"; POD="akq-$RANDOM"
TOKEN=$(task k -- -n auth get secret authentik-api-token -o jsonpath='{.data.token}' | base64 -d)
task k -- -n auth run "$POD" --restart=Never --image=curlimages/curl:latest --command -- \
  curl -sk -H "Authorization: Bearer $TOKEN" \
  "http://authentik-server.auth.svc.cluster.local/api/v3${P}" >/dev/null 2>&1
for i in $(seq 1 30); do
  ph=$(task k -- -n auth get pod "$POD" -o jsonpath='{.status.phase}' 2>/dev/null || true)
  case "$ph" in Succeeded|Failed) break;; esac; sleep 2
done
task k -- -n auth logs "$POD"; task k -- -n auth delete pod "$POD" --ignore-not-found
```

Ids captured 2026-09-04, for phases 3 and 4. The application id to patch is the
**slug** (left column); the app pk is shown only because it is what a policy
binding's `target` points at, which is how the two were joined:

| App slug      | `AuthentikApplication` id | binding pk → `AuthentikAccessPolicy` id | group             |
| ------------- | ------------------------- | --------------------------------------- | ----------------- |
| `longhorn`    | `longhorn`                | `1832be5b-5cc5-48fd-a698-3b78e8d912e7`  | `weebo_admin`     |
| `clickstack`  | `clickstack`              | `459afd98-7e50-4d6f-a743-8f8804661f58`  | `weebo_admin`     |
| `harbor`      | `harbor`                  | `6e3be218-4e35-42b8-bc50-66f3f8536840`  | `weebo_moderator` |
| `s3`          | `s3`                      | `bb5935e8-1563-41cf-b022-5c46e8f50e08`  | `weebo_moderator` |
| `argo`        | `argo`                    | `03a8af6b-2cc2-4f97-928f-8ad4863a2400`  | `weebo_moderator` |
| `che-cluster` | `che-cluster`             | `fb28fcc6-d63f-4e57-b093-73cecf6f6c84`  | `weebo_moderator` |
| `vault`       | `vault`                   | `d9187d75-454a-405f-8d62-41a9679a73ab`  | `weebo_moderator` |

Re-derive with `ak.sh /policies/bindings/` joined to
`ak.sh '/core/applications/?superuser_full_list=true'` on
`binding.target == application.pk`. The `group` column is the live binding's
group, and it is what confirmed the `accessGroup` fix in `sub/values.yaml`.

### Running the importer


The importer lives in the operator repo, checked out at
`/var/mnt/data/git/weebo-authentik` on this machine. It reads only.

```bash
cd /var/mnt/data/git/weebo-authentik

# The API token. mv/main-config#AUTHENTIK_BOOTSTRAP_TOKEN is the same value ESO
# already syncs into the `authentik-api-token` Secret, which is easier to read:
AUTHENTIK_TOKEN=$(cd /var/mnt/data/git/weebo-si && \
  task k -- -n auth get secret authentik-api-token -o jsonpath='{.data.token}' | base64 -d)

# auth.weebo.poc is signed by the weebo private PKI. Either trust it once,
# system-wide -- `task vault:trust-intermediate` from the weebo-si repo -- or
# scope it to this run with --ca-cert / AUTHENTIK_CA_CERT.
AUTHENTIK_TOKEN=$AUTHENTIK_TOKEN cargo run -p importer -- \
  --authentik-url https://auth.weebo.poc \
  --instance-ref main --namespace auth --out import-output
```

Details that bite:

- `--authentik-url` is the **web** base, exactly like `spec.url`. The importer
  appends `/api/v3` itself via `api::instance::split_urls`. Passing
  `https://auth.weebo.poc/api/v3` is accepted (it is trimmed), but on a 0.8.0
  checkout the split did not exist and every call 404s — build from a revision
  at or after 0.9.0.
- Requires the VPN: this one runs from your machine, not from the cluster.
- `--applications <slug,slug>` limits the run to named applications. The
  cluster-scoped kinds (Group / User / Brand / Flow / Outpost) are regenerated
  every run regardless.
- `cargo run -p importer` needs nothing special. Only cargo commands that touch
  _test_ targets need `LIBCLANG_PATH=/usr/lib64` on this machine.
- The output is one YAML file per CR, each already carrying
  `status.authentikId`. **That is the only reason to run it** — the spec it
  writes is a convenience, the id is the payload.

### Phase 0 — foundation (touches no Authentik object) — ✅ done

`AuthentikInstance` only describes how to reach the API;
`AuthentikNamespacePolicy` only gates who may create CRs. Neither has a
counterpart on the Authentik side, so there is nothing to import or adopt.

The operator itself is deployed by `main/templates/authentik/operator.yaml`
(chart 0.10.0, namespace `auth`, its own self-signed webhook issuer). Confirm
it is healthy and actually on 0.10.0 — the CRDs ship in the chart, so an
unsynced operator Application means phase 2b and phase 4 CRs get rejected by
the apiserver (0.6.0 has neither `AuthentikFlow` nor `secretTargets`; 0.7.0 has
no `secretStore.vault.caSecretRef`; 0.9.0 has no `tls.caSecretRef`):

```bash
task k -- -n auth get deploy -l app.kubernetes.io/name=weebo-authentik \
  -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'   # expect :v0.10.0
task k -- get crd | grep -c authentik.weebo.io                       # expect 9
task k -- get crd authentikapplications.authentik.weebo.io -o yaml \
  | grep -c secretTargets                                            # expect >0
task k -- get crd authentikinstances.authentik.weebo.io -o yaml \
  | grep -c caSecretRef                                              # expect 4 (tls + vault)
```

✅ All four pass today. The `authentik-operator` Application reports OutOfSync
on the 9 CRDs — that is ArgoCD's large-CRD diff, and the checks above are the
answer to whether it matters. It does not.

Then, in `main/values.yaml`:

```yaml
authentik:
  sub:
    enabled: true
    foundation:
      enabled: true
      secretStore: { enabled: true }
      namespacePolicy: { enabled: true }
      tls: { caSecretRef: { enabled: true } }
      # vault: { enabled: true }  -- leave OFF until phase 4; see section 3.2
```

Sync, then check the API token landed and the instance connected:

```bash
task k -- -n auth get externalsecret authentik-api-token
task k -- get authentikinstance main -o json | jq '.status.conditions'
task k -- get authentikinstance main -o yaml | sed -n '/^spec:/,/^status:/p'
```

✅ Live today: `Ready=True`, `"instance accepted"`, `url: https://auth.weebo.poc`,
`tls.caSecretRef` → `weebo.poc` / `main-ca.crt` / `auth`,
`secretStore.backend: kubernetes` (no `vault` block yet — correct for pre-phase-4).

> **If the conditions show a TLS error, this is why.** `auth.weebo.poc` is
> served by a `vault-issuer` cert-manager Certificate — the weebo PKI, a
> private CA — and the operator image is `distroless/cc`, whose trust store
> is the public roots and nothing else. Unlike the openbao case in 3.2 the
> `weebo.poc` bundle _does_ cover this cert, so there are two ways to hand it
> over: `foundation.tls.caSecretRef.enabled` (operator >= 0.10.0, reads the
> `weebo.poc` Secret's `main-ca.crt` over the API and adds it on top of the
> platform roots — **on** in `main/values.yaml`, which is why the pin there is
> 0.10.0), or `inject-certs: "enabled"` as a podAnnotation on the operator
> chart, which mounts the same bundle over `/etc/ssl/certs` the way the
> authentik and dex pods already do — the only option on an older operator.
> The CR field keeps the trust decision next to the URL it applies to.
> `spec.tls.insecureSkipVerify` is the third option and is not one — it is a
> no-op before 0.10.0 and turns verification off after it.
>
> Check the Secret exists before blaming the CR — a missing Secret or key is
> a hard reconcile error, deliberately, not a fall-back to the public roots:
>
> ```bash
> task k -- -n auth get secret weebo.poc -o jsonpath='{.data.main-ca\.crt}' | wc -c
> ```
>
> ✅ 303284 bytes today.

> The allow-list is default-deny **once any policy exists**, so
> `namespacePolicy` must already list every namespace that will hold an
> `AuthentikApplication`. It lists `auth` today; extend
> `foundation.namespacePolicy.allowedNamespaces` before putting a CR anywhere
> else. Phases 3 and 4 both put `AuthentikApplication` CRs in `auth`, so
> nothing needs adding for them.

### Phase 1 — groups and the user — ✅ done

Lowest blast radius: cluster-scoped, no Vault secret depends on them, nothing
outside Authentik reads them. Recorded here as the worked example the later
phases refer back to.

1. **Import** (see "Running the importer" above), then compare
   `import-output/authentikgroup-*.yaml` and `authentikuser-*.yaml` against
   `sub/values.yaml`'s `identity` block.

   > `parentRef`, a user's `groupRefs` and an access policy's group are all
   > resolved against the **Authentik** group name (`spec.name`, `weebo_user`),
   > never the CR name (`metadata.name`, `weebo-user`): the operator issues a
   > `/core/groups/?name=` query, it never looks at another CR. Get it wrong and
   > the object adopts fine, then errors on every update with
   > `GroupRefNotFound: group "weebo-user" not found` while the CR it names sits
   > there Ready. The importer always writes the Authentik name, which is
   > another reason to diff against its output rather than hand-write these.
   >
   > `sub/values.yaml` gets this right in the `identity` block: `crName:
weebo-user` / `name: weebo_user`, and `parentRef: weebo_user`,
   > `groupRefs: [weebo_admin]` — underscores throughout on the ref side. It
   > got it **wrong** in every `applications[].accessGroup`, which is the same
   > rule on a different field; see the note at the top of phase 3.

2. **Enable** in `main/values.yaml`, commit, push, sync:

   ```yaml
   identity:
     groups: { enabled: true }
     users: { enabled: true }
   ```

3. **Patch the ids on** (apply dropped them):

   ```bash
   for f in import-output/authentikgroup-*.yaml import-output/authentikuser-*.yaml; do
     kind=$(yq '.kind' "$f"); name=$(yq '.metadata.name' "$f")
     aid=$(yq '.status.authentikId' "$f")
     task k -- patch "$kind" "$name" --subresource=status --type merge \
       -p "{\"status\":{\"authentikId\":\"$aid\"}}"
   done
   ```

4. **Verify** — every object Ready, no duplicates in the Authentik admin UI:

   ```bash
   task k -- get authentikgroups,authentikusers \
     -o custom-columns='KIND:.kind,NAME:.metadata.name,ID:.status.authentikId,READY:.status.conditions[0].status'
   ```

   ✅ Live today:

   | Kind  | Name              | authentikId                            | Ready |
   | ----- | ----------------- | -------------------------------------- | ----- |
   | Group | `weebo-admin`     | `19c70fcb-1d14-4087-b36b-33af9bae3e7c` | True  |
   | Group | `weebo-moderator` | `f5a7df9b-727a-439e-aaf2-5f4b9e1663b1` | True  |
   | Group | `weebo-user`      | `45178a25-380a-4a91-8fa1-0378a93a82c0` | True  |
   | User  | `batleforc`       | `5`                                    | True  |

   Note the user's id is the integer primary key, not a UUID.

5. **Hand over from Terraform:**

   ```bash
   cd 2.terra/auth
   task k -- -n auth delete job terra-state-rm --ignore-not-found
   sed 's/PHASE_PLACEHOLDER/identity/' migration/state-rm-job.yaml | task k -- apply -f -
   task k -- -n auth logs -f job/terra-state-rm

   # then downgrade group.tf to data sources and delete user.tf
   sh migration/rewrite-group-refs.sh
   # drop ./terra-map/user.tf from kustomization.yaml's configMapGenerator
   ```

   ✅ Ran 2026-09-01 22:55, four addresses removed, backup at
   `/terraform/state-backup-identity-20260901-225507.tfstate`. `group.tf` is now
   the `data`-only version, `user.tf` is gone from disk and from
   `kustomization.yaml`.

`group.tf` becomes `data` rather than disappearing, because `vault.tf` builds
`vault_identity_group_alias` off `authentik_group.*.name` and ten other
references read `.id`/`.name`. See the end of section 2.

6. Resume the loop; the plan must meet the section-0 baseline.

### Phase 2a — brand — ✅ done 2026-09-04

The CR half is done: `AuthentikBrand/weebo` is Ready with
`authentikId: `, and the live brand kept
everything the CRD does not model —
`flow_device_code: d8ef5c2a-7abd-4661-a7bb-aed4dd786d98` (the device-code flow,
still correct) and `default_application: null`.

The Terraform half ran on 2026-09-04, in this order — which is the order to
reuse for every later phase, because it is the one that never lets config and
state disagree in the destructive direction:

```bash
cd /var/mnt/data/git/weebo-si

# 1. Confirm the loop is suspended. It is today -- but check, it is a live-only
#    patch (section 4).
task k -- -n argocd get app terra-authentik -o jsonpath='{.spec.syncPolicy.automated}{"\n"}'
#    expect: {"enabled":false,"prune":true,"selfHeal":true}

# 2. Do NOT commit flow.tf yet. Run the state rm first -- the block is already
#    gone from your working tree, so committing before this plans a real
#    delete of the live brand.
task k -- -n auth delete job terra-state-rm --ignore-not-found
sed 's/PHASE_PLACEHOLDER/brand/' 2.terra/auth/migration/state-rm-job.yaml | task k -- apply -f -
task k -- -n auth logs -f job/terra-state-rm
#    expect: "removing authentik_brand.default" and a
#    state-backup-brand-<ts>.tfstate line

# 3. Confirm it left state, and that the flow did not.
task k -- -n auth logs job/terra-state-rm | sed -n '/remaining in state:/,$p' \
  | grep -E 'authentik_brand|authentik_flow'
#    expect: only `data.authentik_brand.authentik-default` and
#    `authentik_flow.token-authentik-flow`

# 4. NOW commit and push the flow.tf edit (brand block removed).
git add 2.terra/auth/terra-map/flow.tf && git commit && git push

# 5. Plan against the section-0 baseline before resuming the loop.
#    (the plan job from section 0; expect 0 add / 6 change / 0 destroy)
```

Delete **only** the `authentik_brand.default` block from `flow.tf` — which is
what the working tree already does. `authentik_flow.token-authentik-flow` and
the `data.authentik_brand.authentik-default` lookup both stay until phase 2b.

Two ordering notes, both already satisfied:

- `flowAuthentication` and friends came from the importer's output, not from
  reading `flow.tf` — that file copies them off the built-in `authentik-default`
  brand rather than naming them. `sub/values.yaml` carries
  `flowAuthentication: default-authentication-flow`,
  `flowInvalidation: default-invalidation-flow`, and empty strings for
  recovery / unenrollment / user-settings, which is what the live brand has.
- `flow_device_code` has no field on `AuthentikBrand` even in 0.10.0, so the
  live brand keeps its stored UUID whoever owns the flow behind it. Adopting
  the brand **before** the flow never leaves the brand pointing at nothing, and
  it is also what frees `flow.tf` of the `authentik_flow...uuid` reference that
  would otherwise block 2b.

### Phase 2b — the device-code flow — ✅ done 2026-09-04

The one flow in `2.terra/auth` that is a `resource` rather than a `data`
lookup. Cluster-scoped, slug-keyed — `status.authentikId` holds the **slug**
(`device-code-flow`), not a UUID.

**Do not start this until phase 2a's `state rm` has run and its `flow.tf` edit
is pushed.** `authentik_brand.default` references
`authentik_flow.token-authentik-flow.uuid`; removing the flow while the brand
block is still in the config is a config error, and removing it from state
while the brand still references it is worse.

```bash
# 1. Import. This writes an AuthentikFlow CR for EVERY flow on the instance,
#    built-ins included. Keep exactly one.
cd /var/mnt/data/git/weebo-authentik
AUTHENTIK_TOKEN=... cargo run -p importer -- \
  --authentik-url https://auth.weebo.poc \
  --instance-ref main --namespace auth --out import-output
ls import-output/authentikflow-*.yaml
diff <(yq '.spec' import-output/authentikflow-device-code-flow.yaml) \
     <(helm template auth-app /var/mnt/data/git/weebo-si/2.argo/helm/auth/sub \
         --set flows.deviceCode.enabled=true \
       | yq 'select(.kind=="AuthentikFlow") | .spec')

# 2. flows: { deviceCode: { enabled: true } } in main/values.yaml, then commit,
#    push and let `auth` -> `auth-app` sync.
#
#    BETTER, and what was actually done: create the CR by hand and patch its
#    status BEFORE the commit lands. ArgoCD then adopts an object that is
#    already Ready, and the create-first collision never happens at all --
#    `kubectl apply` updates spec and leaves the status subresource alone.
#      helm template auth-app 2.argo/helm/auth/sub --set flows.deviceCode.enabled=true \
#        | yq 'select(.kind=="AuthentikFlow")' | task k -- apply -f -
#    followed immediately by step 3. The window is small enough in practice
#    that the operator's first reconcile already sees the id.

# 3. Patch the slug onto the status.
task k -- patch authentikflow device-code-flow --subresource=status --type merge \
  -p '{"status":{"authentikId":"device-code-flow"}}'
task k -- get authentikflow device-code-flow \
  -o custom-columns='NAME:.metadata.name,ID:.status.authentikId,READY:.status.conditions[0].status'

# 4. Verify the brand still points at the same flow (from inside the cluster,
#    so no VPN needed).
TOKEN=$(task k -- -n auth get secret authentik-api-token -o jsonpath='{.data.token}' | base64 -d)
task k -- -n auth run authq --rm -i --restart=Never --image=curlimages/curl:latest --quiet -- \
  curl -sk -H "Authorization: Bearer $TOKEN" \
  http://authentik-server.auth.svc.cluster.local/api/v3/core/brands/
#    the `weebo` brand's flow_device_code must still read
#    d8ef5c2a-7abd-4661-a7bb-aed4dd786d98
```

Parity is already confirmed. The live flow reads:

```
name=device-code-authentik-flow  slug=device-code-flow  title="Device Code Flow"
designation=stage_configuration  authentication=require_authenticated
stages=[]  policies=[]
```

— identical to `sub/values.yaml`'s `flows.deviceCode` block, and the empty
`stages`/`policies` are what make the CRD's inability to model them a non-issue
for this one flow.

Then hand over:

```bash
task k -- -n auth delete job terra-state-rm --ignore-not-found
sed 's/PHASE_PLACEHOLDER/flow/' 2.terra/auth/migration/state-rm-job.yaml | task k -- apply -f -
task k -- -n auth logs -f job/terra-state-rm
```

…and only then delete the `authentik_flow.token-authentik-flow` block from
`flow.tf`. Ran 2026-09-04 16:42, backup
`state-backup-flow-20260904-164256.tfstate`; afterwards the only brand/flow
entries left in state are the three `data.` lookups.

**That empties `flow.tf`.** The only thing left in it would be
`data "authentik_brand" "authentik-default"`, and nothing reads it — it existed
solely to feed the brand resource that phase 2a removed (grep confirms: one
definition, zero references). So phase 2b's `.tf` edit is _delete
`terra-map/flow.tf` and drop its line from `kustomization.yaml`'s
`configMapGenerator`_ — the same shape as `user.tf` in phase 1, and safe for
the same reason: by then neither of its two resources is in state.

**Do not** adopt any of the other imported flows. They are Authentik built-ins
referenced by slug from `data.tf`; a CR over one of them adds a finalizer and
nothing else.

> **The AppProject whitelist blocks this phase until it is fixed.** `auth-app`
> runs in project `infra`, whose `clusterResourceWhitelist`
> (`2.argo/app/values.yaml`) is an allow-list. It named `AuthentikInstance`,
> `AuthentikNamespacePolicy`, `AuthentikUser`, `AuthentikGroup` and
> `AuthentikBrand` — every cluster-scoped kind that existed when it was
> written — but not `AuthentikFlow`, which the operator only gained in 0.7.0.
> The sync fails with:
>
> ```
> resource authentik.weebo.io:AuthentikFlow is not permitted in project infra
> ```
>
> and ArgoCD retries with backoff rather than erroring out, so it shows as a
> sync stuck `Running`, not as a failure. Fixed by adding the kind to
> `2.argo/app/values.yaml` (managed by the `main` Application).
>
> Note what this does **not** affect: phases 3 and 4. `AuthentikApplication`
> and `AuthentikAccessPolicy` are Namespaced, and `namespaceResourceWhitelist`
> is null, which ArgoCD reads as allow-all. Of the six cluster-scoped kinds
> the operator ships, `AuthentikOutpost` is now the only one still absent —
> deliberately, since no phase here creates one.
>
> The CR itself is unaffected either way: it was created and adopted by hand
> before the commit, so the object was live and Ready throughout. The whitelist
> only governs whether ArgoCD may *manage* it.

### Phase 3 — the two proxy applications — ✅ done 2026-09-04

> **Fixed on 2026-09-04, before you get here.** All seven `accessGroup` values
> in `sub/values.yaml` named the **CR** (`weebo-admin`, hyphen) where the
> operator resolves the **Authentik** name (`weebo_admin`, underscore) — the
> same trap the phase-1 note calls out, on the one field that had not been
> checked because no phase had reached it yet. `accessGroup` renders straight
> into `AuthentikAccessPolicy.spec.groupRef`, and
> `crates/domain/src/error.rs` is explicit that a `groupRef` resolves to "an
> `AuthentikGroup`'s Authentik-side name". Every one of the seven now reads
> `weebo_admin` / `weebo_moderator`, matching what `longhorn.tf`,
> `clickstack.tf`, `argo.tf`, `che-cluster.tf`, `harbor.tf`, `s3.tf` and
> `vault.tf` bind today. Had it shipped, every application in phases 3 and 4
> would have adopted cleanly and then left its access policy erroring — an
> application with no bound policy is open to any authenticated user, which the
> operator only reports as advisory (`Ready` stays `True`).

Two applications, four Terraform resources each
(`authentik_provider_proxy`, `authentik_application`,
`authentik_outpost_provider_attachment`, `authentik_policy_binding`), and no
Vault secret anywhere — which is what makes this phase independent of the 3.2
plumbing and safe to do before phase 4.

**Adopt with the CRs pre-created and their status patched before the commit
lands**, exactly as phase 2b did — `kubectl apply` leaves the status
subresource alone, so ArgoCD then adopts an object that is already Ready and
the create-first collision never happens. An application needs two ids:

```bash
task k -- apply -f <rendered CRs>
task k -- -n auth patch authentikapplication longhorn --subresource=status \
  --type merge -p '{"status":{"authentikId":"longhorn"}}'          # the SLUG
task k -- -n auth patch authentikaccesspolicy longhorn-access --subresource=status \
  --type merge -p '{"status":{"authentikId":"<binding pk from the table above>"}}'
```

Result for longhorn: both CRs `Reconciled`/Ready, and the proxy providers
**byte-identical** before and after on all of
`mode`/`internal_host`/`external_host`/`authorization_flow`/`invalidation_flow`/
`intercept_header_auth`/`basic_auth_enabled`/`cookie_domain`/`skip_path_regex`.
Application count stayed 7 and binding count stayed 19 — the check that proves
adoption rather than creation, and the one worth repeating for clickstack.

`longhorn` first; it is the ordinary case (`mode=proxy`,
`internal_host=http://longhorn-frontend.longhorn.svc.cluster.local`,
`external_host=https://longhorn.weebo.poc`, provider pk 6, app slug `longhorn`,
access group `weebo_admin`).

Then `clickstack`, which is the one object whose live configuration the CRD
cannot express: `clickstack.tf` sets `mode = "forward_single"` and deliberately
omits `internal_host`. Adoption preserves both, but confirm it rather than
assuming:

```bash
# after the clickstack CR reports Ready
TOKEN=$(task k -- -n auth get secret authentik-api-token -o jsonpath='{.data.token}' | base64 -d)
task k -- -n auth run authq --rm -i --restart=Never --image=curlimages/curl:latest --quiet -- \
  sh -c "curl -sk -H 'Authorization: Bearer $TOKEN' \
    http://authentik-server.auth.svc.cluster.local/api/v3/providers/proxy/" \
  | python3 -c 'import sys,json; s=sys.stdin.read(); d=json.loads(s[s.find("{\"pagination"):]);
[print(r["name"], r["mode"], repr(r["internal_host"]), r["external_host"]) for r in d["results"]]'
# expect: clickstack forward_single ... https://clickstack.weebo.poc
```

Baseline as of 2026-09-04, before any adoption:

```
clickstack  mode=forward_single  internal_host=http://clickstack-preauth.monitoring.svc.cluster.local:8080  external_host=https://clickstack.weebo.poc
longhorn    mode=proxy           internal_host=http://longhorn-frontend.longhorn.svc.cluster.local          external_host=https://longhorn.weebo.poc
```

Note that `internal_host` on clickstack is **still set** even though
`clickstack.tf` omits it and the last apply proposed `-> null`: Authentik
ignores Terraform's null and keeps the stored value. That is one of the six
permanent plan churners from section 0.

**The operator does not ignore it.** `upsert_proxy_provider_impl` sends
`internal_host: Some(spec.internal_host.clone())` on both create and PATCH — it
is not one of the `None` fields — so `internalHost: ""` **clears** the live
value rather than re-sending it. That is the intended end state (in
`forward_single` the outpost never proxies, which is the whole point of
`clickstack.tf` omitting the field), but it is a real one-way mutation, not a
no-op. Record the pre-value before enabling the CR:

```
clickstack.internal_host = http://clickstack-preauth.monitoring.svc.cluster.local:8080
```

`mode` **is** in the `None` list on both create and PATCH, so `forward_single`
is genuinely preserved — that is the property this phase actually depends on,
and it is verified in the source, not just observed.

> **`internalHost: ""` is rejected — this bit on the first attempt.** The
> original plan was that an empty `internalHost` would be a harmless no-op.
> It is not, and not for the reason the earlier draft of this file gave
> either. Three claims, in order of discovery:
>
> 1. "`""` re-sends the internal_host it already has" — false.
>    `upsert_proxy_provider_impl` passes `internal_host: Some(...)` on both
>    create and PATCH, so the empty string is genuinely sent.
> 2. "so it clears the value" — also false, because it never gets that far.
> 3. What actually happens: Authentik's proxy serializer validates a PATCH
>    that omits `mode` **as if `mode` were the default `proxy`**, and an empty
>    `internal_host` is invalid in proxy mode. The reconcile fails with
>
>    ```
>    AuthentikApplication/clickstack   READY=False
>    error in response: status code 400 Bad Request
>    ```
>
> The two halves of the operator's own strategy collide: omitting `mode` is
> what preserves `forward_single`, and it is also what makes Authentik reach
> for the wrong validator. There is no CR that both preserves the mode and
> sends an empty internal host.
>
> **The fix is to mirror the live value** —
> `internalHost: "http://clickstack-preauth.monitoring.svc.cluster.local:8080"`,
> now in `sub/values.yaml`. It is inert at runtime (in `forward_single` the
> outpost never proxies) but has to be non-empty for the PATCH to be accepted.
> The cost is that the value is no longer described in Terraform *or*
> meaningfully in the chart — if the preauth service is renamed, this string
> has to be changed by hand.
>
> Note the failure was completely safe: a 400 means Authentik wrote nothing,
> so the provider stayed byte-identical throughout and `forward_single` was
> never at risk. The CR simply sat `Ready=False` until the spec was corrected.
> Note also that the operator logs nothing at info level, so the 400 is
> visible only in the CR's own status message — not in
> `logs deploy/authentik-weebo-authentik`, whose most recent lines were three
> days stale.

If `mode` ever comes back as `proxy`, revert it in the Authentik UI
immediately and disable the CR — that regression serves HyperDX's 404 body for
every asset behind the route, which is the exact failure `clickstack.tf`'s
comment block documents.

Outpost attachment needs nothing: `outpostRef` unset means Authentik's
embedded outpost, which is what both
`authentik_outpost_provider_attachment` resources already target, and the
operator appends to the outpost's provider list rather than replacing it. This
is also why the `state rm` for these phases includes the attachment: nothing
replaces it, because nothing needs to.

`PHASE=longhorn` and `PHASE=clickstack` each remove all four addresses; delete
all four blocks from the `.tf` afterwards. `longhorn.tf` and `clickstack.tf`
then have nothing left, so both come out of `kustomization.yaml` — but check
first: both files' policy bindings read `data.authentik_group.weebo_admin.id`,
and that data source is defined in `group.tf`, not in them.

### Phase 4 — the oauth2 applications — ✅ harbor/s3/argo/che done 2026-09-04, vault stays

Read section 3 first. Order: **`harbor` → `s3` → `argo` → `che` → `vault`**.

Before the first one, once:

1. Both prerequisites in 3.2 are **already confirmed live** (the `auth` Vault
   role lists `authentik-weebo-authentik`; `openbao-tls` carries `ca.crt` in
   `auth`). Re-run those two checks anyway, then turn on
   `foundation: { vault: { enabled: true } }` in `main/values.yaml`, commit,
   push, sync. On its own this writes nothing anywhere — it only puts the
   connection block on the `AuthentikInstance`.
2. Confirm the instance still reports Ready and now carries the block:

   ```bash
   task k -- get authentikinstance main -o yaml | sed -n '/^spec:/,/^status:/p'
   task k -- get authentikinstance main -o json | jq '.status.conditions'
   ```

   A malformed vault block surfaces here, before any credential is at stake.
   Note that a wrong CA or an unbound ServiceAccount does _not_: the instance
   carries the connection but never dials it, so the first login happens on the
   first application reconcile. `harbor` being first in the order is what makes
   that a cheap failure.

Then, per app, the same moves plus one:

```bash
# 3. Snapshot the KV entry BEFORE enabling the CR -- this is the one step that
#    overwrites live data rather than just adopting an object.
bao kv get -format=json mv/registry/auth > /tmp/registry-auth-before.json

# 4. applications.harbor.enabled = true in main/values.yaml, commit, push,
#    sync, then patch status.authentikId from the importer's
#    authentikapplication-harbor.yaml.

# 5. Diff the KV entry. All three keys must be byte-identical -- since 0.8.0
#    AUTHENTIK_URL is the same per-application issuer Terraform wrote (3.3),
#    so this diff is expected to be EMPTY.
diff <(jq -S .data.data /tmp/registry-auth-before.json) \
     <(bao kv get -format=json mv/registry/auth | jq -S .data.data)
```

`bao` here means the Vault CLI against `https://vault.weebo.poc`, which needs
the VPN — `task vault -- kv get -format=json -mount=mv registry/auth` from the
weebo-si repo does the token plumbing. Without the VPN, run the same read from
inside the openbao pod the way 3.2's role check does.

Live oauth2 provider baseline, for the "is anything already drifting" question:

| pk  | name          | client_id     | sub_mode         | access_token_validity | signing_key |
| --- | ------------- | ------------- | ---------------- | --------------------- | ----------- |
| 1   | `harbor`      | `harbor`      | `hashed_user_id` | `minutes=10`          | self-signed |
| 5   | `s3`          | `s3`          | `hashed_user_id` | `minutes=10`          | self-signed |
| 2   | `argo`        | `argo`        | `hashed_user_id` | `minutes=10`          | self-signed |
| 3   | `che-cluster` | `che-cluster` | `user_username`  | `hours=10`            | self-signed |
| 4   | `vault`       | `vault`       | `hashed_user_id` | `minutes=10`          | self-signed |

`che-cluster`'s `user_username` and `hours=10` are the two values from the
section-1 table that adoption must preserve; check them again after its CR
reports Ready. All five carry `9c470150-b16e-4d75-be74-0e2f3dceeec9`, the
self-signed certificate — which is what 0.7.0's `signingKey` default resolves
to, so the explicit `signingKey` in `sub/values.yaml` is a no-op here and a
guard against a future default change.

**Outcome, 2026-09-04.** All four ran clean, in order, with an empty KV diff
every time:

| App    | KV path(s)                          | data diff | KV version |
| ------ | ----------------------------------- | --------- | ---------- |
| harbor | `mv/registry/auth`                  | empty     | 1 → 3      |
| s3     | `mv/s3/auth`                        | empty     | 1 → 3      |
| argo   | `mv/argocd/auth`                    | empty     | 1 → 3      |
| che    | `mv/eclipse-che/auth`, `mv/dex/auth`| empty     | 1 → 4, 2 → 5 |

All seven oauth2 providers came back unchanged on `client_id`,
`client_secret`, `client_type`, `sub_mode`, `access_token_validity`,
`signing_key`, `grant_types`, `redirect_uris` and `property_mappings` —
including `che-cluster`'s `sub_mode = user_username` and
`access_token_validity = hours=10`, the two values from section 1's table that
adoption had to preserve. Application count stayed 7, binding count 19.

**The version bump is not a diff.** Each reconcile is a full KV v2 `set`, so
the version increments even when the content is identical — that is why the
check is on `.data.data`, never on the version. Expect it to keep climbing for
as long as the CRs exist.

**Two fields are sent unconditionally on PATCH, and this is the real risk in
phase 4.** `client_secret`, `sub_mode` and `access_token_validity` are `None`
and therefore preserved, but `redirect_uris` and `property_mappings` are built
from the CR spec and **always** sent:

```rust
redirect_uris: Some(redirect_uris),          // Self::redirect_uris(spec)
property_mappings: Some(property_mappings),  // resolved by NAME
```

An empty or wrong list in `sub/values.yaml` therefore **wipes** the live
values — which for `redirect_uris` breaks OIDC login for that application
outright. This is the same shape as the clickstack `internal_host` trap, and
the reason the pre-flight below is not optional:

```bash
# diff every CR's allowedRedirectUris / propertyMappings / clientId / grantTypes
# against the live provider BEFORE enabling anything
helm template auth-app 2.argo/helm/auth/sub --set applications.<app>.enabled=true
ak.sh /providers/oauth2/
ak.sh '/propertymappings/all/?page_size=200'   # to resolve pks to names
```

Run on 2026-09-04, harbor/s3/argo/che-cluster matched the live providers
exactly on all four fields. **`vault` did not** — its live `redirect_uris`
carry duplicates the CR does not, which is the same duplication visible in the
`terraform plan` churn. One more reason it stays in Terraform.

Any diff at all in step 5 is a stop. A changed `AUTHENTIK_CLIENT_SECRET` means
something rotated the credential; a changed `AUTHENTIK_URL` means the CR's slug
does not match the live application's, which would also point every consumer at
an issuer that does not exist. Restore from the snapshot before touching the
next app.

Only then `state rm` the provider, the application, the policy binding **and**
the `vault_kv_secret_v2`, and delete all four blocks from the `.tf` file. The
KV path is now reconciled by the operator instead of Terraform, which is the
point — leaving the `vault_kv_secret_v2` in place would have Terraform and the
operator fight over the same path on every apply.

Two files do not empty out at the end of their phase:

- `che-cluster.tf` has **two** `vault_kv_secret_v2` resources (`che-app` →
  `mv/eclipse-che/auth`, `che-app-2` → `mv/dex/auth`); `PHASE=che` removes both,
  and the CR's two `secretTargets` entries take both over.
- `vault.tf` keeps everything below the provider.

`vault` last or never: `vault.tf` derives an entire OIDC auth backend, two
roles and two identity-group aliases from the provider's client id and secret,
none of which have a CRD equivalent. `PHASE=vault` in the `state rm` job
deliberately exits 1 for that reason. Migrating it means feeding those from
somewhere else first.

---

## 6. Rolling back

Nothing in this migration deletes an Authentik object, so every phase is
reversible while Terraform still holds the state:

- **Before `state rm`** — set the phase's flag back to `false`. ArgoCD will not
  prune the CRs (`prune: false`), so remove them by hand _and_ strip their
  finalizer, or deleting them deletes the real object:

  ```bash
  task k -- patch authentikgroup weebo-admin --type merge \
    -p '{"metadata":{"finalizers":null}}'
  task k -- delete authentikgroup weebo-admin
  ```

  Terraform still owns the object and the next apply is a no-op.

- **After `state rm`** — the job wrote `/terraform/state-backup-<phase>-<ts>.tfstate`
  to the PVC before touching anything. Restore with `terraform state push`
  from a shell on that volume (the read-only peek job in section 0 shows the
  shape; swap `ls` for the push), and revert the `.tf` edits.

- **Phase 4 is still the one exception to "nothing is destroyed"** — less so
  since 0.8.0, but not zero. Adopting an oauth2 app _writes_ its Vault KV path
  (a full KV v2 `set`, so a new version every reconcile) rather than reading
  it. The content should be identical now that `AUTHENTIK_URL` matches (3.3),
  which makes a rollback uneventful in the expected case; it is the
  unexpected case — the diff in phase 4 step 5 came back non-empty — where
  this matters. Restore the snapshot from step 3
  (`bao kv put mv/<path> @before.json`) _after_ the CR is gone, or the
  operator's next reconcile writes its own version straight back. Disable the
  CR first, then restore.
