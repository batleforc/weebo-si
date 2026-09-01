# Moving Authentik from Terraform to the weebo-authentik operator

`2.terra/auth` and the operator can both point at the same Authentik instance
without fighting, so this is done one object at a time, with a working system
after every step. Nothing here ever recreates an Authentik object.

Two files hold the whole migration:

- `2.argo/helm/auth/sub/values.yaml` — the CRs, one `enabled` flag each, all
  `false` today.
- `2.terra/auth/migration/` — the one-shot jobs that make Terraform *forget*
  what the operator has taken over.

**Requires operator 0.8.0, plus the `spec.url` split that landed after it**
(`authentik.operator.version` in `main/values.yaml`). Five changes are
load-bearing here and none of them exists in 0.6.0:

- **`AuthentikFlow`**, cluster-scoped and slug-keyed. `flow.tf`'s
  `token-authentik-flow` was the one Terraform `resource` with no CRD; it now
  has one. New phase 2b.
- **`AuthentikApplication.spec.secretTargets`** — a per-application list of
  Vault paths / Kubernetes Secrets the oauth2 credentials are fanned out to,
  each Vault entry pinning an exact path. This is what turns phase 4 from
  "pick one of three bad options" into a normal phase; section 3 is rewritten
  around it.
- **`AuthentikInstance.spec.secretStore.vault.caSecretRef`** (0.8.0) — the CA
  the operator verifies Vault's TLS with, read from a Kubernetes Secret over
  the API rather than from a mounted file. This is the whole of prerequisite 2
  in 3.2; without it there is no supported way to make the operator trust
  openbao.
- **`AUTHENTIK_URL` is the per-application issuer** (0.8.0). It used to be
  the gateway's REST `base_path`. `upsert_oauth2_provider` now takes the
  application's slug and the gateway carries a `web_base_url` separate from
  the API base, so the credential written out is
  `<spec.url>/application/o/<slug>/` — character for character what
  `harbor.tf`/`s3.tf`/`argo.tf`/`che-cluster.tf` interpolate today. Section
  3.3 used to be a list of consumers to patch around this; it is now a
  no-op.

- **`spec.url` is split into a REST base and a web base** (after 0.8.0). The
  bullet above only holds if the operator can reach the API at all, and in
  0.8.0 it cannot: `gateway_factory.rs` handed `spec.url` to the generated
  client verbatim, while that client appends every path to a base that has to
  end in `/api/v3` (its own default `base_path` is literally `/api/v3`). So
  `url: https://auth.weebo.poc` 404s on every call, and "fixing" it by writing
  `https://auth.weebo.poc/api/v3` feeds the same string to the issuer above
  and writes `.../api/v3/application/o/<slug>/` into all five Vault paths.
  `api::instance::split_urls` now derives both from the web base (and trims a
  stray `/api/v3` rather than honouring it). **Bump
  `authentik.operator.version` to the release carrying this before flipping
  `foundation.enabled`** — every other phase depends on it.

0.7.0 also gives `oauth2.signingKey` a default of
`"authentik Self-signed Certificate"` — the same certificate
`data.authentik_certificate_key_pair.generated` resolves in `data.tf`, so
every provider here is unaffected. Note the shift though: in 0.6.0 an omitted
`signingKey` sent no key at all and adoption preserved whatever was live;
in 0.7.0 an omitted `signingKey` *sets* the self-signed cert. Every CR in
`sub/values.yaml` names it explicitly for that reason. An explicit `null`
still means "no signing key".

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

| Live field | Set by | Survives adoption |
| --- | --- | --- |
| `client_secret` (all oauth2) | Authentik | yes — never rotated by the operator |
| `mode = forward_single` | `clickstack.tf` | yes |
| `sub_mode = user_username` | `che-cluster.tf` | yes |
| `access_token_validity = hours=10` | `che-cluster.tf` | yes |
| `meta_launch_url` | `che-cluster.tf`, `vault.tf` | yes |
| `flow_device_code` on the brand | `flow.tf` | yes |
| `default_application` on the brand | `flow.tf` | yes |

The catch is that "preserved" also means "no longer described anywhere in
git". Those values become invisible state on the live instance. Treat the
table above as a list of things to re-check after any operator upgrade that
starts modeling one of them.

0.7.0 is exactly such an upgrade, and it took one field off this table:
`signing_key` is now modeled *and defaulted*, so an omitted `signingKey` no
longer means "leave it alone" — it means "set the self-signed cert". The value
happens to match on every provider here, but the rule changed. `client_secret`
is still never rotated; what 0.7.0 adds is that the operator now *writes* it
somewhere (section 3), where before it only read it back.

---

## 2. What cannot move

Leave these in Terraform. There is no CRD for them:

- Every `vault_*` resource in `vault.tf`: the OIDC auth backend, its two roles,
  and the two identity-group aliases. These are the reason the `vault`
  application migrates last or never.
- The `data` lookups in `data.tf` — flows, property mappings and the
  self-signed certificate are referenced by slug/name and never created by
  either side. `AuthentikFlow` does not change this: adopting a *built-in* flow
  buys nothing and hands the operator a finalizer on an object Authentik ships.

Two entries left this list in 0.7.0:

- `authentik_flow.token-authentik-flow` (`flow.tf`) now has an `AuthentikFlow`
  CRD — see phase 2b. The CRD models the flow object only, not its stage
  bindings or policies, but that flow has neither, so it is parity.
- `vault_kv_secret_v2` for the five oauth2 apps is no longer stuck in
  Terraform: `secretTargets` lets the operator write those exact paths. See
  section 3.

---

## 3. The oauth2 credentials — read before phase 4

Five oauth2 applications feed a `vault_kv_secret_v2` with their
`client_secret`:

| App | Vault path | Who reads `AUTHENTIK_URL` from it |
| --- | --- | --- |
| harbor | `mv/registry/auth` | nobody in this repo (harbor's OIDC is configured in its own UI) |
| s3 | `mv/s3/auth` | nobody in this repo (rustfs OIDC, same) |
| argo | `mv/argocd/auth` | `main/templates/authentik/auth-secret.yaml` → argocd's OIDC issuer |
| che-cluster | `mv/eclipse-che/auth` | `1.pulu-init/Taskfile.yaml` → `OIDC_ISSUER_URL` |
| che-cluster | `mv/dex/auth` | `main/templates/dex/dex.yaml` → the weebo connector's `issuer` |
| vault | *(none)* | `vault.tf` consumes client_id/secret directly, in Terraform |

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
    path: eclipse-che/auth   # relative to the instance's mount (mv)
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

### 3.2 Two prerequisites — one in this chart, one in Terraform

The instance's default `backend` stays `kubernetes` — nothing should land at
`mv/weebo-authentik/auth/<crName>`. But a Vault *target* reuses the instance's
`secretStore.vault` block for address/mount/auth, and the operator errors the
reconcile if that block is missing. So `foundation.vault.enabled` must be on
before the first phase-4 app, and two things must be true first:

1. **The operator's ServiceAccount must be bound to the `auth` Vault role.**
   That role (`mv_policy`, full CRUD on `mv/*`) bound
   `bound_service_account_names = ["authentik", "default"]` in namespace `auth`
   — and the operator runs as `authentik-weebo-authentik`, which was in
   neither. Done in `2.terra/vault/terra-map/auth-base.tf`:

   ```hcl
   resource "vault_kubernetes_auth_backend_role" "auth-write" {
     role_name                        = "auth"
     bound_service_account_names      = ["authentik", "default", "authentik-weebo-authentik"]
     ...
   ```

   Do not instead point the operator chart at the existing `authentik` SA: the
   authentik server chart already owns that name in this namespace. This one
   still has to be applied by the `terra-vault` job before phase 4 — check
   the live role, not just the `.tf`:

   ```bash
   bao read auth/kubernetes/role/auth   # bound_service_account_names must
                                        # list authentik-weebo-authentik
   ```

2. **The operator must trust openbao's self-signed CA** — `caSecretRef`,
   already set in `sub/values.yaml`. Unlike ESO's `SecretStore`,
   `spec.secretStore.vault` has no `caProvider`, and `spec.tls.
   insecureSkipVerify` covers the *Authentik* API, not Vault. 0.8.0 added the
   field that closes this:

   ```yaml
   caSecretRef:
     name: openbao-tls
     namespace: auth
     key: ca.crt
   ```

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

0.8.0 writes `<spec.url>/application/o/<slug>/`. With `spec.url` =
`https://auth.weebo.poc` and the CR slugs in `sub/values.yaml` matching the
`.tf` ones (they do — `harbor`, `s3`, `argo`, `che-cluster`, `vault`), the
value is byte-identical to Terraform's.

**So the phase-4 KV diff must now be empty.** Not "empty except
`AUTHENTIK_URL`" — empty. A diff on *any* of the three keys means something is
wrong (a slug mismatch, a rotated secret, an instance `url` with a trailing
path) and is a stop-and-investigate, not an expected shape change.

The consumers therefore need no changes, and every one of them should read the
key rather than keep its own copy of the issuer:

| Consumer | Reads | State |
| --- | --- | --- |
| `main/templates/authentik/auth-secret.yaml` | `mv/argocd/auth#AUTHENTIK_URL` → argocd's OIDC issuer | already did |
| `1.pulu-init/Taskfile.yaml` | `mv/eclipse-che/auth#AUTHENTIK_URL` → `OIDC_ISSUER_URL` | already did |
| `main/templates/dex/dex.yaml` | `mv/dex/auth#AUTHENTIK_URL` → the weebo connector's `issuer` | switched to it; used to hardcode `dex.mainConnector.issuer` |
| harbor, s3 | — | configured in their own UIs, out of this repo |

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
  a resource dropped from `kustomization.yaml` before its `state rm` is a
  resource Terraform plans to **delete for real**. `state rm` always comes
  first.
- **Never `kubectl delete` an adopted CR** unless you mean it. They carry
  finalizers: deleting the CR deletes the Authentik object behind it. This is
  also why `auth-app`'s sync policy sets `prune: false` — removing a CR from
  git must not be enough to destroy a provider.
- **Suspend the Terraform apply loop** for the duration of each phase, so the
  PostSync hook cannot race the state edit:

  ```bash
  kubectl -n argocd patch app terra-authentik --type merge \
    -p '{"spec":{"syncPolicy":{"automated":null}}}'
  ```

  Re-enable it (`"automated":{"prune":true,"selfHeal":true}`) once the phase's
  `terraform plan` is clean.

---

## 5. The phases

Each phase is the same five moves. Only the objects change.

### Phase 0 — foundation (touches no Authentik object)

`AuthentikInstance` only describes how to reach the API;
`AuthentikNamespacePolicy` only gates who may create CRs. Neither has a
counterpart on the Authentik side, so there is nothing to import or adopt.

The operator itself is already deployed by
`main/templates/authentik/operator.yaml` (chart 0.8.0, namespace `auth`, its
own self-signed webhook issuer). Confirm it is healthy and actually on 0.8.0
first — the CRDs ship in the chart, so an unsynced operator Application means
phase 2b and phase 4 CRs get rejected by the apiserver (0.6.0 has neither
`AuthentikFlow` nor `secretTargets`; 0.7.0 has no `caSecretRef`):

```bash
kubectl -n auth get deploy -l app.kubernetes.io/name=weebo-authentik \
  -o jsonpath='{.items[*].spec.template.spec.containers[*].image}'   # expect :v0.8.0
kubectl get crd | grep authentik.weebo.io   # expect 9 (8 + authentikflows)
kubectl get crd authentikapplications.authentik.weebo.io -o yaml \
  | grep -c secretTargets                                            # expect >0
kubectl get crd authentikinstances.authentik.weebo.io -o yaml \
  | grep -c caSecretRef                                              # expect >0
```

Then, in `main/values.yaml`, set:

```yaml
authentik:
  sub:
    enabled: true
    foundation:
      enabled: true
      secretStore: { enabled: true }
      namespacePolicy: { enabled: true }
      # vault: { enabled: true }  -- leave OFF until phase 4; see section 3.2
```

Sync, then check the API token landed and the instance connected:

```bash
kubectl -n auth get externalsecret authentik-api-token
kubectl get authentikinstance main -o yaml | yq '.status.conditions'
```

> The allow-list is default-deny **once any policy exists**, so
> `namespacePolicy` must already list every namespace that will hold an
> `AuthentikApplication`. It lists `auth` today; extend
> `foundation.namespacePolicy.allowedNamespaces` before putting a CR anywhere
> else.

### Phase 1 — groups and the user

Lowest blast radius: cluster-scoped, no Vault secret depends on them, nothing
outside Authentik reads them.

```bash
# 1. Import ids from the live instance (needs network access to Authentik and
#    a read token — mv/main-config#AUTHENTIK_BOOTSTRAP_TOKEN works).
#    --authentik-url is the WEB base, like spec.url: the importer appends
#    /api/v3 itself. On a 0.8.0 checkout it did not, and every call 404s --
#    check out a revision carrying api::instance::split_urls.
git clone https://github.com/batleforc/weebo-authentik && cd weebo-authentik
AUTHENTIK_TOKEN=<token> cargo run -p importer -- \
  --authentik-url https://auth.weebo.poc \
  --instance-ref main --namespace auth --out import-output
```

Compare `import-output/authentikgroup-*.yaml` and `authentikuser-*.yaml`
against `sub/values.yaml`'s `identity` block — the importer reads the live
instance, so **its output wins over anything written here by hand**. Then:

```bash
# 2. Turn the CRs on in main/values.yaml and let ArgoCD sync:
#      identity: { groups: {enabled: true}, users: {enabled: true} }

# 3. Patch the ids on (apply dropped them).
for f in import-output/authentikgroup-*.yaml import-output/authentikuser-*.yaml; do
  kind=$(yq '.kind' "$f"); name=$(yq '.metadata.name' "$f")
  aid=$(yq '.status.authentikId' "$f")
  kubectl patch "$kind" "$name" --subresource=status --type merge \
    -p "{\"status\":{\"authentikId\":\"$aid\"}}"
done

# 4. Verify — every object Ready, no duplicates in the Authentik admin UI.
kubectl get authentikgroups,authentikusers \
  -o custom-columns=KIND:.kind,NAME:.metadata.name,ID:.status.authentikId,READY:.status.conditions[0].status
```

Only once that is green, hand over from Terraform:

```bash
cd 2.terra/auth
kubectl -n auth delete job terra-state-rm --ignore-not-found
sed 's/PHASE_PLACEHOLDER/identity/' migration/state-rm-job.yaml | kubectl apply -f -
kubectl -n auth logs -f job/terra-state-rm

# then downgrade group.tf to data sources and delete user.tf
sh migration/rewrite-group-refs.sh
# drop ./terra-map/user.tf from kustomization.yaml's configMapGenerator
```

`group.tf` becomes `data` rather than disappearing, because `vault.tf` builds
`vault_identity_group_alias` off `authentik_group.*.name` and will keep doing
so forever. Re-enable the apply loop; `terraform plan` must report **no
changes**.

### Phase 2a — brand

Same five moves with `brand: { enabled: true }` and
`PHASE=brand`. Take `flowAuthentication` and friends from the importer's
output, not from reading `flow.tf` — that file copies them off the built-in
`authentik-default` brand rather than naming them.

After `PHASE=brand`, delete the `authentik_brand.default` block from `flow.tf`
— but *only* that block. `authentik_flow.token-authentik-flow` and the
`data.authentik_brand.authentik-default` lookup both stay until phase 2b.

`flow_device_code` has no field on `AuthentikBrand` even in 0.7.0, so the live
brand keeps its stored UUID whoever owns the flow behind it. Adopt the brand
before the flow: that ordering never leaves the brand pointing at nothing, and
it is also what frees `flow.tf` of the `authentik_flow...uuid` reference that
would otherwise block 2b.

### Phase 2b — the device-code flow (0.7.0)

The one flow in `2.terra/auth` that is a `resource` rather than a `data`
lookup. Cluster-scoped, slug-keyed — `status.authentikId` holds the **slug**
(`device-code-flow`), not a UUID.

```bash
# 1. Import. This writes an AuthentikFlow CR for EVERY flow on the instance,
#    built-ins included. Keep exactly one.
AUTHENTIK_TOKEN=<token> cargo run -p importer -- \
  --authentik-url https://auth.weebo.poc \
  --instance-ref main --namespace auth --out import-output
ls import-output/authentikflow-*.yaml
diff <(yq '.spec' import-output/authentikflow-device-code-flow.yaml) \
     <(helm template auth-app 2.argo/helm/auth/sub \
         --set flows.deviceCode.enabled=true \
       | yq 'select(.kind=="AuthentikFlow") | .spec')

# 2. flows: { deviceCode: { enabled: true } } in main/values.yaml, sync.

# 3. Patch the slug onto the status.
kubectl patch authentikflow device-code-flow --subresource=status --type merge \
  -p '{"status":{"authentikId":"device-code-flow"}}'

# 4. Verify the brand still points at the same flow.
curl -sH "Authorization: Bearer $TOKEN" https://auth.weebo.poc/api/v3/core/brands/ \
  | jq '.results[] | select(.domain=="weebo") | .flow_device_code'
```

Then `PHASE=flow` for the `state rm` job, and delete the
`authentik_flow.token-authentik-flow` block from `flow.tf`. `flow.tf`'s
`authentik_brand.default` references it as `.uuid`, so phase 2a must already
have removed that block — do not run 2b before 2a.

**Do not** adopt any of the other imported flows. They are Authentik built-ins
referenced by slug from `data.tf`; a CR over one of them adds a finalizer and
nothing else.

### Phase 3 — the two proxy applications

`longhorn` first; it is the ordinary case. Then `clickstack`, which is the one
object whose live configuration the CRD cannot express: `clickstack.tf` sets
`mode = "forward_single"` and deliberately omits `internal_host`. Adoption
preserves both, but confirm it rather than assuming:

```bash
# after the clickstack CR reports Ready
curl -sH "Authorization: Bearer $TOKEN" \
  https://auth.weebo.poc/api/v3/providers/proxy/ \
  | jq '.results[] | select(.name=="clickstack") | {mode, internal_host, external_host}'
# expect: mode "forward_single", internal_host ""
```

If `mode` ever comes back as `proxy`, revert it in the Authentik UI
immediately and disable the CR — that regression serves HyperDX's 404 body for
every asset behind the route, which is the exact failure `clickstack.tf`'s
comment block documents.

Outpost attachment needs nothing: `outpostRef` unset means Authentik's
embedded outpost, which is what both
`authentik_outpost_provider_attachment` resources already target, and the
operator appends to the outpost's provider list rather than replacing it.

### Phase 4 — the oauth2 applications

Read section 3 first. Order: **`harbor` → `s3` → `argo` → `che` → `vault`**.

Before the first one, once:

1. Confirm both prerequisites in 3.2 — the `auth` role really lists
   `authentik-weebo-authentik` on the live Vault, and `caSecretRef` is on the
   rendered instance — then turn on
   `foundation: { vault: { enabled: true } }`. On its own this writes nothing
   anywhere — it only puts the connection block on the `AuthentikInstance`.
2. Confirm the instance still reports Ready. A malformed vault block surfaces
   here, before any credential is at stake. Note that a wrong CA or an
   unbound ServiceAccount does *not*: the instance carries the connection but
   never dials it, so the first login happens on the first application
   reconcile. `harbor` being first in the order is what makes that a cheap
   failure.

Then, per app, the same five moves plus one:

```bash
# 3. Snapshot the KV entry BEFORE enabling the CR — this is the one step that
#    overwrites live data rather than just adopting an object.
bao kv get -format=json mv/registry/auth > /tmp/registry-auth-before.json

# 4. applications.harbor.enabled = true, sync, patch status.authentikId from
#    the importer's authentikapplication-harbor.yaml.

# 5. Diff the KV entry. All three keys must be byte-identical -- since 0.8.0
#    AUTHENTIK_URL is the same per-application issuer Terraform wrote (3.3),
#    so this diff is expected to be EMPTY.
diff <(jq -S .data.data /tmp/registry-auth-before.json) \
     <(bao kv get -format=json mv/registry/auth | jq -S .data.data)
```

Any diff at all is a stop. A changed `AUTHENTIK_CLIENT_SECRET` means something
rotated the credential; a changed `AUTHENTIK_URL` means the CR's slug does not
match the live application's, which would also point every consumer at an
issuer that does not exist. Restore from the snapshot before touching the next
app.

Only then `state rm` the provider, the application, the policy binding **and**
the `vault_kv_secret_v2`, and delete all four blocks from the `.tf` file. The
KV path is now reconciled by the operator instead of Terraform, which is the
point — leaving the `vault_kv_secret_v2` in place would have Terraform and the
operator fight over the same path on every apply.

`vault` last or never: `vault.tf` derives an entire OIDC auth backend, two
roles and two identity-group aliases from the provider's client id and secret,
none of which have a CRD equivalent. Migrating it means feeding those from
somewhere else first.

---

## 6. Rolling back

Nothing in this migration deletes an Authentik object, so every phase is
reversible while Terraform still holds the state:

- **Before `state rm`** — set the phase's flag back to `false`. ArgoCD will not
  prune the CRs (`prune: false`), so remove them by hand *and* strip their
  finalizer, or deleting them deletes the real object:

  ```bash
  kubectl patch authentikgroup weebo-admin --type merge \
    -p '{"metadata":{"finalizers":null}}'
  kubectl delete authentikgroup weebo-admin
  ```

  Terraform still owns the object and the next apply is a no-op.

- **After `state rm`** — the job wrote `/terraform/state-backup-<phase>-<ts>.tfstate`
  to the PVC before touching anything. Restore with `terraform state push`
  from a shell on that volume, and revert the `.tf` edits.

- **Phase 4 is still the one exception to "nothing is destroyed"** — less so
  since 0.8.0, but not zero. Adopting an oauth2 app *writes* its Vault KV path
  (a full KV v2 `set`, so a new version every reconcile) rather than reading
  it. The content should be identical now that `AUTHENTIK_URL` matches (3.3),
  which makes a rollback uneventful in the expected case; it is the
  unexpected case — the diff in phase 4 step 5 came back non-empty — where
  this matters. Restore the snapshot from step 3
  (`bao kv put mv/<path> @before.json`) *after* the CR is gone, or the
  operator's next reconcile writes its own version straight back. Disable the
  CR first, then restore.
