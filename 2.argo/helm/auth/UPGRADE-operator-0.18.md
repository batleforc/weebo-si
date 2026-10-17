# Upgrade weebo-authentik 0.15.0 -> 0.18.1

Runbook préparé le 2026-10-17. Les modifs de l'étape 0 sont dans le même
changement que ce fichier ; les étapes 1 à 4 restent à exécuter.

## Ce qui casse (changelog 0.16.0 -> 0.18.1)

1. **`spec.instanceRef` devient un objet** (0.16.0). Nos 9
   `AuthentikApplication` ont `instanceRef: main`. Migration officielle :
   opérateur arrêté, nouvelles CRDs appliquées,
   `weebo-authentik-operator migrate-instance-ref` (`--dry-run` d'abord),
   opérateur relancé, manifests réécrits en `instanceRef: {name: main}`.
2. **Un `path` Vault doit rester sous `<pathPrefix>/<namespace>/`** (0.16.0),
   soit `weebo-authentik/auth/` chez nous. Nos 8 chemins sont tous en dehors
   (`angos/auth`, `argocd/auth`, `batlehub/auth`, `dex/auth`,
   `eclipse-che/auth`, `forgejo/auth`, `s3/auth`,
   `weebo-si-hardening/endpoint-gateway`). Sans correctif, les apps passent
   `Ready: False` et n'écrivent plus leurs credentials. Correctif :
   `secretStore.vault.pathGrants` (0.18.0) sur l'`AuthentikInstance`.
3. **`secretTargets[].name` est requis**, cibles Vault comprises.

## Vérifié, sans impact

- Noms des ressources identiques avec `releaseName: authentik` : le SA reste
  `authentik-weebo-authentik`, le rôle Vault `auth` reste valide. Seul le
  Certificate du webhook est renommé (`-webhook`), l'ancien est prune.
- Nos values (`replicaCount`, `image.tag: v…`, `podDisruptionBudget.enabled`)
  passent le `values.schema.json` strict ; l'image
  `ghcr.io/batleforc/weebo-authentik-operator:v0.18.1` existe.
- Les CRDs passent de `crds/` à `templates/crds/`
  (`helm.sh/resource-policy: keep`). Nouveau kind `AuthentikLocalInstance`
  namespacé : rien à ajouter au whitelist du projet `infra`.
- `webhook.failurePolicy: Fail` existait déjà.
- Le label `authentik.weebo.io/instance-token` (0.17.0) ne concerne que les
  `AuthentikLocalInstance` : non utilisé.
- **Reprise des valeurs Vault existantes** : la propriété est la clé `owner`
  des custom-metadata KV (`weebo-operator-kit`,
  `crates/weebo-kit-adapters/src/secret_vault.rs`, `owner_of`). Ce que
  Terraform et la 0.15.0 ont écrit n'en a pas -> `None` -> repris à la
  première écriture. Pas de conflit attendu sur les 8 chemins.

## Étape 0 -- préparation (fait)

- [x] `main/values.yaml` : `operator.version: 0.18.1`.
- [x] `sub/templates/applications/applications.yaml` : `instanceRef` en
      objet ; `name` par défaut = `path` avec `/` -> `-` (`dex-auth`).
- [x] `sub/templates/foundation/instance.yaml` : `pathGrants` calculés depuis
      les cibles Vault des apps activées, pour le namespace `auth`.
- [x] Rendu comparé au live : seuls écarts = `instanceRef`, les `name`, les
      `pathGrants`, plus des valeurs par défaut de CRD que l'API pose au live
      (`negate`, `clientType`, `attributes`, `insecureSkipVerify`), identiques
      en 0.18.1.
- [x] Sauvegarde des CRs (2026-10-17, hors repo : `~/backups/authentik-upgrade-2026-10-17/`) :
      `kubectl get authentikapplications,authentikaccesspolicies,authentikgroups,authentikusers,authentikbrands,authentikflows,authentikscopemappings,authentiknamespacepolicies,authentikinstances -A -o yaml > backup-authentik-crs.yaml`
- [x] Sauvegarde du `.data.data` des 8 chemins KV (`backup-kv.json`, même dossier) (`mv/<path>`) pour la
      comparaison finale.

Pour refaire le rendu :

```sh
yq '.authentik.sub' 2.argo/helm/auth/main/values.yaml > /tmp/sub-values.yaml
helm template auth-app 2.argo/helm/auth/sub -n auth -f /tmp/sub-values.yaml
```

## Étape 1 -- geler

- [x] Couper l'auto-sync de l'app racine (`main`), d'`auth`, de
      `authentik-operator` et de `auth-app` (sinon selfHeal remet tout).
- [x] `kubectl -n auth scale deploy/authentik-weebo-authentik --replicas=0`

## Étape 2 -- CRDs et migration

- [x] Passer le webhook en `failurePolicy: Ignore` le temps de la migration :
      il valide les `UPDATE` d'`authentikapplications` et l'opérateur est à 0,
      donc le patch de migration serait refusé. Sauvegarde de la config et des
      CRDs 0.15.0 dans `~/backups/authentik-upgrade-2026-10-17/`. Le sync
      d'`authentik-operator` (étape 3) le remet en `Fail`.
- [x] Appliquer les CRDs 0.18.1 :
      ```sh
      helm template authentik oci://ghcr.io/batleforc/charts/weebo-authentik \
        --version 0.18.1 -n auth \
        | yq 'select(.kind == "CustomResourceDefinition")' \
        | kubectl apply --server-side --force-conflicts -f -
      ```
- [x] Lancer `operator migrate-instance-ref --dry-run`, puis
      sans `--dry-run`, dans un pod ponctuel : image
      `ghcr.io/batleforc/weebo-authentik-operator:v0.18.1`, SA
      `authentik-weebo-authentik`, namespace `auth`.
- [x] Vérifier (9 apps migrées) :
      `kubectl get authentikapplications -A -o jsonpath='{..instanceRef}'`
      -> des objets `{"name":"main"}`.

## Étape 3 -- pousser et resynchroniser dans l'ordre

- [x] Commit + push (`develop` @ d8089e8a).
- [x] Sync `authentik-operator` (CRDs déjà là, déploiement v0.18.1) : sync partiel d'`auth`' sur la seule Application `authentik-operator`, webhook revenu en `Fail`.
- [x] Sync `auth-app` (même méthode) : l'instance (wave 2) reçoit les `pathGrants` avant
      les applications (wave 5).

## Étape 4 -- vérifier

- [x] Tous les CRs `Ready: True` (29/29). Lire `status.conditions`, pas les logs
      (l'opérateur ne logue rien en info).
- [x] Nombre d'objets Authentik inchangé (9 applications, bindings stables).
- [x] Les 8 chemins KV identiques à la sauvegarde, versions inchangées, `owner` posé sur chacun.
- [ ] Un login OIDC (argo ou che) et un login proxy (clickstack,
      `forward_single`).
- [x] Réactiver l'auto-sync (`main`, `auth` ; les deux autres via le sync d'`auth`').

## Reste ouvert

- `authentik-operator` reste `OutOfSync`, comme avant l'upgrade : les CRDs
  du chart déclarent `categories: []`, `shortNames: []` et
  `additionalPrinterColumns: []`, que l'API server ne stocke pas. Écart
  cosmétique ; à corriger dans le chart ou par un `ignoreDifferences`.

## Retour arrière

Le schéma stocké change : revenir en 0.15.0 demande de réappliquer les
anciennes CRDs (`crds/` du chart 0.15.0) et de remettre `instanceRef` en
texte depuis `backup-authentik-crs.yaml`. Le garde-fou réel est le dry-run
de l'étape 2 et le diff de l'étape 0.

## Optionnel, plus tard

Le chart expose maintenant un Service `authentik-weebo-authentik-metrics`
(port 9090, activé par défaut), scrapable par otel-cluster.
