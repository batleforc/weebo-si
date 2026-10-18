# Migration de la base d'Authentik vers CNPG

Runbook préparé le 2026-10-18. Les manifests de l'étape 0 sont dans le même
changement que ce fichier. À supprimer une fois le nettoyage (étape 6) fait.

Toutes les commandes `kubectl` utilisent le kubeconfig admin Talos, qui ne
passe pas par Authentik et reste donc utilisable pendant la coupure :

```sh
export KUBECONFIG=$PWD/0.config/kubeconfig.yaml
```

## Où on en est

- Authentik 2026.8.0, base dans la PostgreSQL embarquée du chart (sous-chart
  Bitnami, image `postgres:17.11-bookworm`), StatefulSet
  `authentik-postgresql`, PVC `data-authentik-postgresql-0` de 8 Gi en
  `local-path`. Le chart la désactive par défaut depuis 2026.x.
- CNPG 1.30.0 tourne déjà (namespace `database`), avec `forgejo-pg` et
  `batlehub-pg` en PostgreSQL 18.4 sur Longhorn.
- **Redis : rien à migrer.** Authentik n'en utilise plus, et le chart 2026.8.0
  n'en livre plus. Le `redis.enabled: true` de nos values ne faisait rien et
  est retiré. Aucun pod ni PVC Redis ne reste dans `auth`.
- Mot de passe : le serveur et le worker se connectent avec
  `POSTGRES_PASSWORD`, qui vient de `mv/main-config#AUTHENTIK_POSTGRES_USER_PASSWORD`
  (vault-webhook, config par défaut d'Authentik `env://POSTGRES_PASSWORD`).
  C'est aussi le mot de passe du rôle `authentik` dans l'ancienne base. CNPG
  reprend la même valeur : seul l'hôte change pour Authentik.

## Ce qui change

- `main/templates/authentik/postgres.yaml` (nouveau) :
  - SecretStore `authentik-db` (wave -3, rôle `auth`) ;
  - ExternalSecret `authentik-pg-cred` (wave -2, basic-auth `authentik` + le
    mot de passe ci-dessus) ;
  - Cluster `authentik-pg` (wave -1, 1 instance, 10 Gi Longhorn), avec
    `bootstrap.initdb.import` (type `microservice`) depuis
    `authentik-postgresql.auth.svc`.
- `main/templates/authentik/authentik.yaml` : `authentik.postgresql.host:
  authentik-pg-rw`, `postgresql.enabled` piloté par
  `authentik.legacyPostgres.enabled` (encore `true`), bloc `redis` retiré.
- `main/values.yaml` : `authentik.postgres` et `authentik.legacyPostgres`.

**Argo CD n'attend pas l'import.** Il n'a pas de health check pour les
`Cluster` CNPG : le champ health de `forgejo-pg` et de `batlehub-pg` est vide
dans leurs Applications, donc une wave -1 est « saine » dès sa création. Un
sync complet basculerait Authentik sur une base encore vide. D'où le sync en
deux temps de l'étape 3.

Montée de version majeure au passage : 17 vers 18.4, par
`pg_dump`/`pg_restore`. Authentik ne demande aucune extension. Si l'ancienne
base en contient une absente de l'image CNPG, l'import échoue avant toute
bascule, et le retour arrière est immédiat (*Retour arrière*, cas 1).

## Étape 0 -- préparation (fait)

- [x] Manifests ci-dessus. `helm template` de `auth/main` OK.
- [x] Rendu du chart Authentik avant et après : seul
      `AUTHENTIK_POSTGRESQL__HOST` change (`authentik-postgresql` devient
      `authentik-pg-rw`), mêmes objets, l'ancienne PostgreSQL reste.
- [x] `kubectl apply --dry-run=server` du SecretStore, de l'ExternalSecret et
      du Cluster : acceptés, webhook CNPG compris.

## Étape 1 -- geler

- [ ] Couper l'auto-sync de `main`, puis d'`auth` et d'`authentik`, dans cet
      ordre : `main` réécrit la spec d'`auth`, et `auth` celle d'`authentik`.
      ```sh
      for app in main auth authentik; do
        kubectl -n argocd patch application $app --type merge \
          -p '{"spec":{"syncPolicy":{"automated":null}}}'
      done
      ```
- [ ] Arrêter les écritures. L'ancienne PostgreSQL reste allumée, c'est la
      source de l'import :
      ```sh
      kubectl -n auth scale deploy/authentik-server deploy/authentik-worker --replicas=0
      ```
      **Début de la coupure SSO.** L'opérateur weebo-authentik reçoit des 503
      et réessaie : c'est sans effet.

## Étape 2 -- pousser

- [ ] Commit et push sur `develop`. L'auto-sync étant coupé, rien ne bouge.

## Étape 3 -- créer la base et attendre l'import

- [ ] Sync partiel d'`auth` sur les trois nouveaux objets seulement :
      ```sh
      kubectl -n argocd patch application auth --type merge -p '{"operation":{"initiatedBy":{"username":"runbook-cnpg"},"sync":{"resources":[
        {"group":"external-secrets.io","kind":"SecretStore","name":"authentik-db","namespace":"auth"},
        {"group":"external-secrets.io","kind":"ExternalSecret","name":"authentik-pg-cred","namespace":"auth"},
        {"group":"postgresql.cnpg.io","kind":"Cluster","name":"authentik-pg","namespace":"auth"}]}}}'
      ```
- [ ] Le Secret existe (`kubectl -n auth get secret authentik-pg-cred`),
      puis l'import se termine :
      ```sh
      kubectl -n auth get pods -l cnpg.io/cluster=authentik-pg -w
      kubectl -n auth logs -l cnpg.io/cluster=authentik-pg,cnpg.io/jobRole=import --tail=-1 | grep -iE "error|fatal|warn" || true
      kubectl -n auth wait cluster.postgresql.cnpg.io/authentik-pg --for=condition=Ready --timeout=15m
      ```
- [ ] Comparer quelques volumes entre l'ancienne base et la nouvelle :
      ```sh
      Q="select (select count(*) from authentik_core_user), (select count(*) from authentik_core_application), (select count(*) from authentik_core_group), (select count(*) from authentik_flows_flow)"
      kubectl -n auth exec authentik-postgresql-0 -c postgresql -- /vault/vault-env sh -c \
        "PGPASSWORD=\"\$POSTGRES_PASSWORD\" psql -h 127.0.0.1 -U authentik -d authentik -tAc '$Q'"
      kubectl -n auth exec authentik-pg-1 -c postgres -- psql -U postgres -d authentik -tAc "$Q"
      ```
      Les deux lignes doivent être identiques.

## Étape 4 -- basculer

- [ ] Sync partiel d'`auth` sur l'Application `authentik`, puis sync
      d'`authentik`. Le chart remet les replicas, avec le nouvel hôte :
      ```sh
      kubectl -n argocd patch application auth --type merge -p '{"operation":{"initiatedBy":{"username":"runbook-cnpg"},"sync":{"resources":[
        {"group":"argoproj.io","kind":"Application","name":"authentik","namespace":"argocd"}]}}}'
      kubectl -n argocd patch application authentik --type merge -p '{"operation":{"initiatedBy":{"username":"runbook-cnpg"},"sync":{}}}'
      ```
- [ ] Server et worker `Running`, sans erreur de base dans les logs
      (`kubectl -n auth logs deploy/authentik-server | grep -i postgres`).
      **Fin de la coupure SSO.**

## Étape 5 -- vérifier

- [ ] Authentik est bien sur la nouvelle base, et plus personne sur
      l'ancienne :
      ```sh
      kubectl -n auth exec authentik-pg-1 -c postgres -- psql -U postgres -tAc \
        "select count(*) from pg_stat_activity where datname='authentik' and usename='authentik'"
      ```
      Ce nombre doit être supérieur à 0.
- [ ] Tous les CR weebo-authentik `Ready: True` (29/29) :
      ```sh
      kubectl get authentikapplications,authentikaccesspolicies,authentikgroups,authentikusers,authentikbrands,authentikflows,authentikscopemappings -A \
        -o custom-columns=KIND:.kind,NAME:.metadata.name,READY:.status.conditions[0].status
      ```
- [ ] Un login OIDC (Argo CD ou Che) et un login proxy (ClickStack,
      `forward_single`).
- [ ] Sync complet d'`auth` (rien ne doit plus changer), puis réactiver
      l'auto-sync de `main`, ce qui réactive celui d'`auth` et d'`authentik`.

## Étape 6 -- nettoyage (quelques jours plus tard)

- [ ] `authentik.postgres.import.enabled: false` et
      `authentik.legacyPostgres.enabled: false`. Retirer aussi
      `postgresql.primary`, `postgresql.auth`, `postgresql.serviceAccount` et
      l'objet `authentik-postgresql-auth` des `additionalObjects`, devenus
      inutiles. CNPG ne relit pas `bootstrap` après la création : la base ne
      bouge pas.
- [ ] Supprimer le PVC de l'ancienne base, que la désactivation du sous-chart
      laisse derrière elle :
      `kubectl -n auth delete pvc data-authentik-postgresql-0`.
- [ ] Supprimer ce fichier ; cocher « Migrer Authentik vers CNPG » dans
      `0.docs/content/docs/left-todo.md`.

## Retour arrière

1. **Avant l'étape 4** (import en échec ou volumes différents) : rien n'a
   basculé. Supprimer le Cluster
   (`kubectl -n auth delete cluster.postgresql.cnpg.io authentik-pg`),
   remettre server et worker à 1 réplique, réactiver l'auto-sync, puis
   revenir sur le commit.
2. **Après l'étape 4** : revenir sur le commit (l'hôte redevient
   `authentik-postgresql`) et resynchroniser `authentik`. L'ancienne base est
   intacte, dans l'état du gel : ce qui a été écrit depuis la bascule est
   perdu (sessions, événements, et toute modification faite entre-temps).

## Hors migration, vu pendant la préparation

- `authentik-server` a redémarré 22 fois en 39 jours, la dernière le
  2026-10-18 à 11:03. Sur ce dernier arrêt, le seul dont on a les logs, le
  processus serveur est tué par un signal 7 (SIGBUS, `unix_wait_status(7)`)
  pendant `applying django migrations` au démarrage, puis repart. Aucun autre
  pod du cluster n'a redémarré à ce moment-là. Une piste : `/dev/shm`, 64 Mi
  par défaut. À investiguer à part, après la migration, pour ne pas mélanger
  les causes.
- Ajouter dans `1.pulu-conf` un health check Argo CD pour
  `postgresql.cnpg.io/Cluster`. Les waves attendraient alors les bases de
  Forgejo, de BatleHub et d'Authentik.
- Aucune sauvegarde CNPG n'existe (ni `ScheduledBackup`, ni plugin barman),
  pour aucune des trois bases. Authentik y garde maintenant aussi ses
  sessions et sa file de tâches.
