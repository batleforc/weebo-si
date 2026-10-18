---
title: "RFC 0002 — La brique de liaison entre opérateurs"
description: "Relier les CR de deux opérateurs par des en-têtes link.weebo.io, un petit contrôleur weebo-link et des hooks d'admission natifs, sans CRD"
rfc: 0002
status: Draft
authors: [batleforc]
created: 2026-10-18
updated: 2026-10-18
decided:
brick: 2.argo/helm/link, github.com/batleforc/weebo-link
supersedes: []
superseded-by: []
---

# RFC 0002 — La brique de liaison : en-têtes `link.weebo.io`, `weebo-link` et hooks d'admission

- **Dépôts :** weebo-si (déploiement, règles), `weebo-link` (nouveau
  contrôleur). Aucun opérateur produit n'est modifié.
- **Base :** weebo-operator-kit v0.17.0 (runtime), Kubernetes
  `ValidatingAdmissionPolicy` (GA), weebo-authentik 0.18.1, weebo-stalwart
  (RFC 0001)
- **Premier lien :** `AuthentikUser` → `StalwartAccount` (RFC 0001, D7)
- **Contrainte :** aucune dépendance à Kyverno. La brique `hook` peut
  disparaître, et la liaison doit lui survivre.

## Résumé

Chaque opérateur weebo ne connaît que son produit (RFC 0001, D7). Quand un
objet d'un produit doit en faire exister un dans un autre, par exemple un
utilisateur Authentik et sa boîte Stalwart, le lien passe par cette brique.
Elle tient en trois pièces, sans aucun CRD :

- **les en-têtes** : l'annotation `link.weebo.io/<cible>: enabled`,
  posée dans Git sur l'objet source, déclare le lien. Sur la cible, des
  labels et annotations `link.weebo.io/*` disent d'où elle vient et où en
  est le lien ;
- **`weebo-link`** : un petit contrôleur sans état. Il lit les règles de
  lien dans sa configuration (values Helm), crée les cibles et les tient à
  jour. Au départ de la source, il les passe dans un **état sûr**
  (`Locked`) au lieu de les supprimer ;
- **les hooks** : des `ValidatingAdmissionPolicy` natives de l'apiserver,
  en CEL, rendues par le même chart. Elles valident les en-têtes et
  réservent l'écriture des cibles à weebo-link. Elles n'ont ni serveur
  webhook ni moteur tiers, et tiennent même quand weebo-link est arrêté.

Cette RFC concerne quiconque relie deux briques, ou retire un utilisateur.

## Motivation

### Aujourd'hui

- La RFC 0001 sort de weebo-stalwart le suivi des `AuthentikUser`. Il faut
  quand même :
  1. qu'un utilisateur Authentik ait sa boîte avant son premier login ;
  2. qu'un utilisateur qui part voie sa boîte verrouillée.
- Aucun opérateur ne doit lire le CRD d'un autre. Mettre le lien dans
  weebo-authentik ou dans weebo-stalwart couplerait deux produits dans un
  même opérateur, et il faudrait recommencer pour chaque paire (Authentik →
  Forgejo, Authentik → Che…).
- Kyverno sait générer des objets, mais la brique `hook` n'est pas
  garantie de rester. De plus, un `generate` supprime la cible quand la
  source disparaît. Pour une boîte mail, c'est le mauvais réflexe : la boîte
  resterait active et sans propriétaire (`Orphan`), sauf à imposer une
  garde et un départ en deux temps.

### Une fois en place

- Dans `auth/sub/values.yaml`, `links: [stalwart]` sur un utilisateur
  donne un `StalwartAccount` `mail/<crName>` en quelques secondes.
- `isActive: false` le passe en `state: Locked`.
- Retirer l'utilisateur, ou seulement son en-tête, se fait en **un seul
  commit**. weebo-link passe la boîte en `Locked` et la garde, détachée,
  visible et réactivable. Si weebo-link était arrêté à ce moment, il le
  fait à son redémarrage : la cible garde la trace de sa source.
- Un nouveau lien, c'est une entrée dans les values de `2.argo/helm/link`,
  sans code.

### Objectifs et non-objectifs

| Objectif | Non-objectif |
| --- | --- |
| Créer un CR cible depuis un objet source annoté | Recopier des secrets (c'est `secretTargets` / ExternalSecrets) |
| Recopier quelques champs (identité, état actif) | Transformer des données de façon arbitraire, ou appeler une API produit |
| Au départ de la source, mettre la cible en état sûr, même après une panne | Supprimer des données produit |
| Zéro CRD, zéro dépendance tierce | Remonter un status dans la source |
| Des liens entièrement déclarés dans Git, par les admins | Des liens définis par les équipes au runtime |

## Explication pour l'exploitant

### Ce qui est installé

L'Application Argo `link`, nouveau chart `2.argo/helm/link`. Elle passe
après les opérateurs, dont elle a besoin des CRD :

| Wave | Objet | Rôle |
| --- | --- | --- |
| 0 | ConfigMap `weebo-link-rules` | les règles, rendues depuis `links:` |
| 0 | ClusterRole / Binding | dérivés des mêmes règles (sources en lecture, cibles en écriture) |
| 0 | `ValidatingAdmissionPolicy` + `…Binding` | les hooks (en-têtes, cibles réservées) |
| 1 | Deployment `weebo-link` | le contrôleur (1 réplique active, lease du kit) |

### Donner une boîte à un utilisateur

```yaml
# 2.argo/helm/auth/sub/values.yaml
identity:
  users:
    items:
      - crName: alice
        username: alice
        email: alice@weebo.poc
        isActive: true
        groupRefs: [weebo_user]
        links: [stalwart]          # rendu en annotation link.weebo.io/stalwart: enabled
```

weebo-link crée :

```yaml
apiVersion: stalwart.weebo.io/v1alpha1
kind: StalwartAccount
metadata:
  name: alice
  namespace: mail
  labels:
    app.kubernetes.io/managed-by: weebo-link
    link.weebo.io/link: authentik-user-stalwart-account
    link.weebo.io/state: Linked               # Linked | Detaching | Detached
  annotations:
    link.weebo.io/source: authentik.weebo.io/AuthentikUser/auth/alice
    link.weebo.io/source-uid: 6f1c…           # l'UID, pour ne pas confondre avec une source recréée
spec:
  domainRef: { name: weebo.poc }
  name: alice                  # spec.username de la source
  state: Active                # isActive → Active, sinon Locked
  deletionPolicy: Orphan
```

```console
$ kubectl -n mail get stalwartaccount -l link.weebo.io/link -L link.weebo.io/state
NAME    ADDRESS           READY   REASON       AGE   STATE
alice   alice@weebo.poc   True    Reconciled   20s   Linked
```

### Retirer un utilisateur

Un seul commit : on le retire des values, ou on retire `stalwart` de ses
`links`.

1. Argo CD supprime l'`AuthentikUser`, ou retire son en-tête.
2. weebo-link voit la cible sans source. Il applique `onRemoval` : un patch
   `spec.state: Locked` et le label `state: Detaching`.
3. Quand l'expression `safe` de la règle est vraie (`Locked`, `Ready` à
   jour), il pose `state: Detached`. La boîte reste dans Stalwart,
   verrouillée avec ses mails, et son CR reste visible.

```console
$ kubectl -n mail get stalwartaccount -l link.weebo.io/state=Detached
NAME    ADDRESS           READY   REASON       AGE
alice   alice@weebo.poc   True    Reconciled   41d
```

Si Alice revient avec le même `crName` et `links: [stalwart]`, weebo-link
rattache le CR détaché, met à jour `source-uid`, et repasse la boîte en
`Active`. Supprimer définitivement une boîte reste un geste explicite : on
supprime le CR après avoir passé sa `deletionPolicy` à `Delete`.

## Design

### Vocabulaire

| Terme | Sens |
| --- | --- |
| **Source** | L'objet qui porte l'en-tête (`AuthentikUser`). Écrit dans Git, possédé par son opérateur. weebo-link n'y écrit jamais. |
| **Cible** | Le CR fabriqué (`StalwartAccount`). Écrit par weebo-link, réconcilié par son opérateur. |
| **Lien** | Une règle : kind source, kind cible, mapping, état sûr. |
| **En-tête** | Une annotation ou un label `link.weebo.io/*`. |
| **État sûr** | L'état de la cible qu'on peut laisser sans source, sans dommage. Défini par la brique cible. |

### En-têtes

| En-tête | Posé sur | Par | Sens |
| --- | --- | --- | --- |
| annotation `link.weebo.io/<header>: enabled` | source | Git (chart de la source) | opt-in au lien dont le `header` vaut `<header>` (`stalwart`). Aucune autre valeur n'est admise : il n'y a pas de paramètre. |
| label `link.weebo.io/link: <lien>` | cible | weebo-link | la règle qui possède ce CR. C'est le sélecteur du contrôleur, des hooks et des alertes. |
| annotation `link.weebo.io/source: <groupe>/<Kind>/<ns>/<nom>` | cible | weebo-link | la source attendue, qui permet de retrouver un départ manqué |
| annotation `link.weebo.io/source-uid` | cible | weebo-link | l'UID de la source liée. Une source supprimée puis recréée sous le même nom est un rattachement explicite, pas une continuité. |
| label `link.weebo.io/state: Linked \| Detaching \| Detached` | cible | weebo-link | où en est le lien (label pour les sélecteurs) |
| label `app.kubernetes.io/managed-by: weebo-link` | cible | weebo-link | convention |

Le domaine `link.weebo.io` ne recoupe pas celui des annotations du kit
(`<produit>.weebo.io/…`). Les opérateurs ignorent les annotations qu'ils ne
connaissent pas, donc un en-tête sur un `AuthentikUser` ne change rien pour
weebo-authentik.

### Une règle de lien

Les values du chart `link` sont rendues telles quelles dans la ConfigMap
`weebo-link-rules`, et relues à chaud :

```yaml
links:
  - name: authentik-user-stalwart-account
    header: stalwart                      # link.weebo.io/stalwart: enabled
    source:
      apiVersion: authentik.weebo.io/v1alpha1
      kind: AuthentikUser
      namespaces: [auth]
    target:
      apiVersion: stalwart.weebo.io/v1alpha1
      kind: StalwartAccount
      namespace: mail
      name: { cel: source.metadata.name }
      spec:                               # littéral, ou {cel: …} évalué sur la source
        domainRef: { name: weebo.poc }
        name: { cel: source.spec.username }
        state: { cel: 'source.spec.isActive ? "Active" : "Locked"' }
        deletionPolicy: Orphan
      immutable: [spec.name]              # changement → Conflict, jamais de renommage
    onRemoval:
      patch:
        spec: { state: Locked }
      safe: { cel: >-
        target.spec.state == "Locked" && has(target.status) &&
        target.status.observedGeneration == target.metadata.generation &&
        target.status.conditions.exists(c, c.type == "Ready" && c.status == "True") }
      then: Keep                          # Keep (Detached) | Delete
```

- Une feuille est soit un littéral YAML, soit `{cel: "<expr>"}` évalué
  avec `source` (et `target` pour `safe`). Pas de boucle, pas d'appel
  externe : seulement de la lecture de champs, des opérateurs et le
  ternaire.
- Une expression qui **échoue** à l'évaluation (champ absent sans `has()`)
  ne vaut jamais `true` : un mapping en erreur n'est pas appliqué, et un
  `safe` en erreur laisse la cible en `Detaching`. Dans les deux cas, un
  Event et une métrique sont émis. C'est vérifié : sans `has(target.status)`,
  une cible jamais réconciliée fait échouer `safe` au lieu de le rendre
  faux.
- Les entiers JSON sont des `int` CEL, comme dans l'apiserver
  (`json_to_cel` de `kube-cel`). Avec la conversion serde par défaut de la
  crate `cel`, `generation == 3` vaut `false` sans erreur (*Vérifications*).
- La règle est validée au chargement : apiVersion et kind résolus par
  discovery, expressions CEL compilées, champs `immutable` présents dans le
  mapping. Une règle invalide est refusée seule, avec un Event et une
  métrique. Les autres continuent.
- Une règle **retirée** des values ne déclenche rien : ses cibles gardent
  leur dernier état, et une métrique signale des cibles au label `link`
  inconnu. Retirer une règle n'est jamais un départ en masse.

### Cycle de vie d'une cible

| Situation | Action de weebo-link |
| --- | --- |
| Source annotée, pas de cible | server-side apply de la cible (fieldManager `weebo-link/<lien>`), état `Linked` |
| Source modifiée | ré-apply : seuls les champs du mapping sont possédés ; les finalizers et le status de l'opérateur cible ne sont pas touchés |
| Champ `immutable` modifié côté source | rien n'est appliqué ; Event `Conflict` sur la source ; métrique |
| Une cible du même nom existe, **sans** label `link` | jamais d'adoption (règle du kit) : Event `TargetExists` sur la source |
| Source supprimée, désannotée, ou UID différent | `onRemoval.patch`, état `Detaching` |
| `Detaching` et `safe` vrai | `then: Keep` → état `Detached` ; `then: Delete` → suppression (la `deletionPolicy` de la cible s'applique) |
| `Detached`, source revenue (même nom, annotée) | rattachement : ré-apply du mapping, nouveau `source-uid`, `Linked` |

Le contrôleur n'a **aucun finalizer sur les sources**. Il ne retient la
suppression d'aucun objet d'un autre opérateur. Les départs manqués
pendant une panne sont retrouvés au redémarrage et à chaque resync (5 min
par défaut, comme `STEADY_REQUEUE_SECS` du kit) : une cible dont la source
n'existe plus est traitée comme un départ.

### Les hooks

Les hooks sont des `ValidatingAdmissionPolicy`, évaluées par l'apiserver
lui-même : pas de webhook, pas de `failurePolicy` qui s'ouvre quand un pod
tombe.

**`link-headers`** : sur les kinds source des règles, un en-tête
`link.weebo.io/*` ne vaut que `enabled`, et seulement pour un `header`
connu.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: link-headers
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [authentik.weebo.io]      # rendu depuis les sources des règles
        apiVersions: ["*"]
        resources: [authentikusers]
        operations: [CREATE, UPDATE]
  validations:
    - expression: >-
        !has(object.metadata.annotations) ||
        object.metadata.annotations.all(k,
          !k.startsWith('link.weebo.io/') ||
          (k.substring(14) in ['stalwart'] && object.metadata.annotations[k] == 'enabled'))
      messageExpression: "'en-tête link.weebo.io/* inconnu ou valeur différente de enabled (RFC 0002)'"
```

**`link-targets`** : sur les kinds cibles, seul weebo-link crée un CR qui
porte un en-tête `link.weebo.io/*`, et seul lui change sa spec ou ces
en-têtes. Tout le reste reste ouvert à tous : les finalizers et le status
de l'opérateur cible, les annotations du kit (`force-orphan`,
`rotate-secret`, `import-pending`) posées par un humain ou par l'importer,
et la suppression. Les en-têtes sont comparés comme des ensembles
`clé=valeur`, labels et annotations confondus, parce que l'ordre
d'itération d'une map CEL n'est pas garanti.

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingAdmissionPolicy
metadata:
  name: link-targets
spec:
  failurePolicy: Fail
  matchConstraints:
    resourceRules:
      - apiGroups: [stalwart.weebo.io]
        apiVersions: ["*"]
        resources: [stalwartaccounts]
        operations: [CREATE, UPDATE]
  variables:
    - name: newHeaders
      expression: >-
        (has(object.metadata.labels)
          ? object.metadata.labels.filter(k, k.startsWith('link.weebo.io/')).map(k, 'l:' + k + '=' + object.metadata.labels[k])
          : []) +
        (has(object.metadata.annotations)
          ? object.metadata.annotations.filter(k, k.startsWith('link.weebo.io/')).map(k, 'a:' + k + '=' + object.metadata.annotations[k])
          : [])
    - name: oldHeaders
      expression: >-
        request.operation != 'UPDATE' ? [] :
        (has(oldObject.metadata.labels)
          ? oldObject.metadata.labels.filter(k, k.startsWith('link.weebo.io/')).map(k, 'l:' + k + '=' + oldObject.metadata.labels[k])
          : []) +
        (has(oldObject.metadata.annotations)
          ? oldObject.metadata.annotations.filter(k, k.startsWith('link.weebo.io/')).map(k, 'a:' + k + '=' + oldObject.metadata.annotations[k])
          : [])
    - name: linked
      expression: "size(variables.newHeaders) > 0 || size(variables.oldHeaders) > 0"
    - name: isLink
      expression: "request.userInfo.username == 'system:serviceaccount:weebo-link:weebo-link'"
    - name: sameSpec
      expression: >-
        request.operation == 'UPDATE' &&
        (has(object.spec) == has(oldObject.spec)) &&
        (!has(object.spec) || object.spec == oldObject.spec)
    - name: sameHeaders
      expression: >-
        variables.newHeaders.all(h, h in variables.oldHeaders) &&
        variables.oldHeaders.all(h, h in variables.newHeaders)
  validations:
    - expression: "variables.isLink || !variables.linked || (variables.sameSpec && variables.sameHeaders)"
      messageExpression: "'ce CR appartient à un lien link.weebo.io : sa spec et ses en-têtes link.weebo.io/* sont écrits par weebo-link (RFC 0002)'"
      reason: Forbidden
```

Chaque `has()` est nécessaire. Une première version comparait
`object.metadata.annotations == oldObject.metadata.annotations` sans garde.
Sur un CR sans annotations, l'expression plantait, et c'est
`failurePolicy: Fail` qui refusait à sa place, pour la mauvaise raison.

Le chart rend les `resourceRules` et la liste des `header` depuis les
règles. Les deux bindings sont en `validationActions: [Deny]` (`[Audit]`
pendant le rollout).

### Décisions

| # | Décision | Pourquoi |
| --- | --- | --- |
| D1 | Un contrôleur dédié, `weebo-link`, et non Kyverno | La brique `hook` peut disparaître. Un `generate` Kyverno supprime aussi la cible au départ de la source, alors qu'il faut la verrouiller. weebo-link fait « patcher puis garder », et retrouve un départ manqué grâce aux en-têtes de la cible. |
| D2 | Les règles vivent dans la configuration de weebo-link, sans CRD | Peu de liens, tous définis par les admins, tous dans Git. Un CRD `Link` ajouterait un objet par lien, un schéma et un status pour la même information. Repli si des équipes veulent leurs propres liens (*Travaux futurs*). |
| D3 | L'opt-in est un en-tête sans paramètre sur la source | C'est la convention `inject-certs` de weebo-si, et l'auteur de la source décide dans Git. Tout le reste (namespace, domaine, nom) est figé dans la règle : un en-tête ne permet rien d'autre qu'oui ou non. |
| D4 | Mapping en CEL, limité à la lecture et au ternaire, évalué par `kube-cel` | C'est le langage de l'apiserver, des VAP et des `x-kubernetes-validations`. `kube-cel` 0.8 (kube-rs, sur `cel` 0.13) ajoute au cœur de CEL les extensions de Kubernetes (`substring`, listes, ensembles…) et sa conversion JSON. Pas de templating Helm à double échappement. |
| D5 | Départ = patch vers l'état sûr, la cible est gardée (`Detached`) | Une boîte ne se perd pas par un retrait de values. C'est réversible, et la RFC 0001 (D8) le demande. La suppression reste un `then: Delete` explicite, par règle. |
| D6 | Aucun finalizer ni aucune écriture sur la source | weebo-link n'interfère jamais avec un objet d'un autre opérateur, ni avec un prune d'Argo CD. Les en-têtes de la cible suffisent à retrouver un départ. |
| D7 | Server-side apply, fieldManager par lien | weebo-link ne possède que les champs de son mapping. Les finalizers et le status de l'opérateur cible ne sont jamais en conflit. |
| D8 | Hooks en `ValidatingAdmissionPolicy`, pas de webhook | Évaluées dans l'apiserver : elles tiennent quand weebo-link est arrêté, sans `failurePolicy` qui s'ouvre et sans certificat à gérer. |
| D9 | Jamais d'adoption d'une cible existante | C'est la règle du kit. Une cible sans label `link` reste à son auteur. Pour la rattacher, il faut un geste explicite (*Exploitation*). |
| D10 | Sur le runtime du kit, sans le template opérateur | Ce n'est pas un opérateur produit : ni instance, ni gateway distante, ni CRD. Il reprend du kit le lease, la santé, l'OTLP, les métriques, les Events, `cog`, `checks.yml`/`publish.yml` et le chart `weebo-operator-lib`. Le contrôleur sur types dynamiques reste dans weebo-link, car `WatchScope::api` et le squelette `controller` du kit sont typés (`DynamicType = ()`). On le versera au kit si un second utilisateur apparaît (règle des deux opérateurs). |

### Architecture

Un dépôt Rust `weebo-link`, en hexagonal comme les opérateurs :

| Crate | Contenu |
| --- | --- |
| `domain` | `Rule`, `Mapping` (littéral ou CEL), états `Linked`/`Detaching`/`Detached`, la décision pure « que faire de cette paire source/cible » |
| `application` | `reconcile_source`, `reconcile_target`, `sweep` (resync complet) ; ports `Sources`, `Targets`, `Rules` |
| `adapters-inbound` | un watcher `DynamicObject` par kind source et par kind cible (filtré sur le label `link`), rechargement de la ConfigMap |
| `adapters-outbound` | server-side apply et patch sur `Api<DynamicObject>`, discovery, Events |
| `operator` | le binaire : lease, santé, OTLP, métriques du kit |
| `testkit` | envtest du kit avec deux CRD factices (source et cible), sans les vrais opérateurs |

Le contrôleur est sans état. La vérité est dans les sources (Git), dans
les en-têtes des cibles et dans les règles.

### Contrat d'une brique cible

Pour être la cible d'un lien, une brique publie dans sa RFC ou dans la doc
de son opérateur :

1. le kind cible et les champs qu'un lien peut renseigner ;
2. son **état sûr** : ce qu'il faut patcher, et l'expression `safe` qui le
   confirme. Pour `StalwartAccount` : `state: Locked`, puis `Ready` à jour
   (RFC 0001). Une cible sans données propres dit « aucun » et peut prendre
   `then: Delete` ;
3. une `deletionPolicy` qui ne détruit rien par défaut.

L'opérateur cible n'a aucun code à ajouter, et ne sait pas qu'il est lié.

### Ce qui change dans weebo-si

- **`auth/sub/templates/identity/users.yaml`** rend `links` en en-têtes :

  ```yaml
  metadata:
    name: {{ .crName }}
    annotations:
      argocd.argoproj.io/sync-wave: "4"
  {{- range .links }}
      link.weebo.io/{{ . }}: enabled
  {{- end }}
  ```

- **`2.argo/helm/link`** : le chart (Application imbriquée vers le chart OCI
  `weebo-link`, comme les opérateurs), les values `links:`, les VAP.
- **Argo CD** : rien à ignorer. Les cibles ne sont dans aucune Application,
  donc elles ne sont ni suivies ni prunées. Les en-têtes de la source sont
  dans Git.

## Sécurité

- **Qui crée un lien :** qui peut écrire la source, c'est-à-dire le dépôt et
  l'Application `auth-sub`. Ces droits donnent déjà la main sur le compte
  Authentik lui-même. L'en-tête n'a pas de paramètre : il ne peut viser ni
  un autre namespace, ni un autre domaine, ni un autre nom que ceux de la
  règle.
- **Qui définit une règle :** qui peut écrire les values de
  `2.argo/helm/link`, donc les admins de la plateforme.
- **Privilèges Kubernetes de weebo-link**, rendus depuis les règles :
  - `get/list/watch` sur les kinds source ;
  - `get/list/watch/create/patch` sur les kinds cibles (et `delete` si une
    règle a `then: Delete`) ;
  - lecture de sa ConfigMap, Events, Lease.

  Il n'a aucun Secret ni aucun droit sur les CRD qui ne sont pas dans une
  règle.
- **Côté produit :** les cibles passent par l'admission de l'opérateur
  cible et par sa `NamespacePolicy`, comme pour n'importe quel auteur.
  weebo-link n'a aucun jeton produit.
- **Rayon d'impact :** un weebo-link compromis peut créer, verrouiller ou
  déverrouiller des comptes dans `mail`. Il ne peut ni lire de mail, ni
  toucher aux comptes d'envoi des apps (autres namespaces, et label `link`
  absent), ni écrire dans `auth`.
- **Contournements :**
  - *weebo-link arrêté :* pas de création ni de verrouillage, mais les VAP
    tiennent. Au retour, le resync rattrape tout. Pendant la panne, un user
    retiré d'Authentik ne peut déjà plus se connecter par OIDC, mais ses
    App Passwords restent valides (RFC 0001, *Exploitation*).
  - *Un CR cible écrit à la main avec un faux label `link` :* refusé par
    `link-targets`.
  - *Une source recréée sous le même nom par quelqu'un d'autre :*
    l'UID diffère, donc l'ancienne cible passe d'abord en `Detached` avant
    un rattachement explicite.
  - *Compte JIT créé avant le lien :* la cible échoue en
    `StalwartObjectAlreadyExists` (RFC 0001, D9). La reprise passe par
    `weebo-stalwart-importer` ; weebo-link ne fait rien de plus.
- **Données :** aucun secret recopié. Seuls les champs du mapping sont lus
  sur la source.

## Exploitation

- **Mode d'échec :** voir les contournements. weebo-link n'est sur le
  chemin d'aucun Pod ni d'aucune admission. Arrêté, il ne bloque rien ; il
  retarde seulement les créations et les verrouillages.
- **Rollout :**
  1. `users.yaml` rend `links` (aucun effet tant que weebo-link n'est pas
     là).
  2. weebo-link avec la règle, VAP en `Audit`, `links: [stalwart]` sur un
     utilisateur de test.
  3. Test de bout en bout : création, `isActive: false`, retrait en un
     commit, retour de l'utilisateur, départ pendant que weebo-link est
     arrêté (le resync doit verrouiller).
  4. VAP en `Deny`, puis `links: [stalwart]` sur tous les utilisateurs qui
     ont une boîte.
- **Rollback :** couper l'Application `link`. Les cibles restent, dans leur
  dernier état, comme des CR ordinaires. Les VAP partent avec le chart.
- **Importer un compte JIT sous une cible liée** (`StalwartObjectAlreadyExists`) :
  passer le binding `link-targets` en `Audit`, lancer
  `weebo-stalwart-importer`, puis repasser en `Deny`. Si l'importer
  réapplique exactement la spec de weebo-link, il passe sans ça.
- **Rattacher une cible existante** (créée à la main avant le lien) : poser
  à la main le label `link` et l'annotation `source`, avec la VAP en
  `Audit`, ou supprimer la cible en `Orphan` et laisser weebo-link la
  recréer. Le compte Stalwart revient alors par l'importer (RFC 0001).
- **Observabilité :**
  - `kubectl get <cible> -A -l link.weebo.io/link -L link.weebo.io/state` ;
  - les Events sur la source (`TargetExists`, `Conflict`) et sur la cible ;
  - les métriques préfixées `weebo_link` (`links_targets{link,state}`,
    `links_rule_errors{link}`, `links_orphan_targets`) et le gauge leader
    du kit, vers otel-cluster ;
  - alertes : une cible `Detaching` depuis plus de 10 min (état sûr jamais
    atteint), une règle en erreur, pas de leader.
- **Montée de version :** weebo-link suit les tags du kit, comme les
  opérateurs. Une nouvelle version d'un CRD source ou cible ne change que
  les règles, qui sont validées par discovery au chargement.

## Alternatives considérées

1. **Kyverno `generate`** (brouillon initial de cette RFC). Il n'y a pas de
   code à écrire. Mais il dépend de la brique `hook`, qui peut disparaître,
   et il supprime la cible au départ de la source. Il faut alors une garde
   qui refuse le départ et impose deux commits. Écarté.
2. **Un CRD `Link`** par lien, lu par weebo-link. Il apporte un status par
   lien et une délégation possible aux équipes, au prix d'un objet de plus
   par lien. Ce n'est pas nécessaire tant que les liens sont l'affaire des
   admins (D2), et la porte reste ouverte.
3. **Un kind « source » dans chaque opérateur cible**
   (`StalwartAccountSource`, brouillon de la RFC 0001). Écarté par la RFC
   0001, D7.
4. **Metacontroller (`DecoratorController`).** Il fonctionne par hooks
   HTTP et annotations, donc il est proche dans l'esprit. Mais c'est une
   dépendance tierce de plus, et ses enfants sont liés par ownerRef dans le
   namespace de la source : la cible ne peut pas être dans `mail`, et un
   départ la supprime par le garbage collector.
5. **kro / Crossplane Compositions.** Ils créent un CRD par composition,
   l'inverse de « pas d'objet en plus », plus un contrôleur tiers.
6. **Générer les cibles dans Helm**, avec le chart `mail` qui lirait la
   liste des users d'`auth/sub`. Il n'y a aucun moteur, mais deux charts
   partagent les mêmes values. Surtout, au départ d'un user, Argo CD
   prunerait la cible au lieu de la verrouiller.
7. **Un webhook mutant ou validant servi par weebo-link** au lieu des VAP.
   Il est plus expressif, mais c'est un serveur de plus sur le chemin de
   l'admission. En `Fail` il bloque quand weebo-link tombe, en `Ignore` il
   s'ouvre. Les VAP font la même chose dans l'apiserver.

## Inconvénients et risques

- **Un composant de plus à maintenir.** Il reste petit : pas d'API produit,
  pas de secret, pas de CRD. Le gros du code est la lecture de règles et un
  apply générique, testés en envtest sur des CRD factices.
- **Le contrôleur dynamique n'est pas dans le kit** (D10). C'est un écart
  assumé, à remonter dans le kit dès qu'un second utilisateur apparaît.
- **Des cibles `Detached` s'accumulent.** C'est voulu, puisque ce sont des
  boîtes conservées. Le nettoyage est un geste humain, aidé par le
  sélecteur `link.weebo.io/state=Detached`.
- **CEL dans les values Helm.** Les erreurs apparaissent au chargement de
  la règle, pas au `helm template`. Le chart lance un `weebo-link
  check-rules` en test Helm, et la CI des charts aussi. La feature
  `validation` de `kube-cel` fournit un `VapEvaluator` qui permettrait aussi
  à `check-rules` de tester les VAP sans apiserver. Elle n'est pas encore
  essayée.

## Questions ouvertes

| # | Question | Bloquant |
| --- | --- | --- |
| Q1 | ~~Quelle crate CEL en Rust ?~~ **Tranchée :** `kube-cel` 0.8 (sur `cel` 0.13), avec la conversion `json_to_cel` (entiers en `int`). | ~~oui~~ |
| Q2 | ~~La VAP `link-targets` laisse-t-elle passer les écritures légitimes ?~~ **Tranchée :** pas dans sa première forme. La forme ci-dessus, qui ne compare que la spec et les en-têtes `link.weebo.io/*`, passe les 18 scénarios. | ~~oui~~ |
| Q3 | ~~Kubernetes du cluster ?~~ **Tranchée :** v1.36.2 (`1.pulu-*/Pulumi.dev.yaml`). Les VAP et leurs `variables` sont GA. | ~~non~~ |
| Q4 | Rattachement d'une cible `Detached` : automatique au retour de la source (proposé), ou seulement avec un en-tête explicite `link.weebo.io/reattach` sur la source ? | non |
| Q5 | Faut-il une règle `AuthentikGroup` → `StalwartGroup` dès la v0.1.0, ou attendre le premier besoin ? | non |
| Q6 | Où publier les règles en doc : une page générée depuis les values de `2.argo/helm/link` ? | non |

### Vérifications (2026-10-18)

**Q2 et `link-headers`.** Un kube-apiserver v1.36.2 local (la version du
cluster), avec etcd et des CRD factices `StalwartAccount` et
`AuthentikUser`. Chaque scénario est joué en impersonation, sous le compte
de weebo-link, celui de l'opérateur, un humain ou l'importer.

| Scénario | Attendu | Première forme | Forme retenue |
| --- | --- | --- | --- |
| weebo-link crée une cible liée ; change `spec.state` | OK | OK | OK |
| un humain crée une cible au label `link` | refus | refus | refus |
| l'opérateur pose son finalizer ; écrit `status` (sous-ressource) | OK | OK | OK |
| un humain pose `force-orphan` ou `rotate-secret` | OK | **refus** | OK |
| l'importer pose puis retire `import-pending` | OK | **refus** | OK |
| l'importer fait un SSA forcé avec une spec identique | OK | OK | OK |
| un humain change `spec.state` | refus | refus | refus |
| un humain retire `link.weebo.io/link`, change `state` ou `source` | refus | refus | refus |
| un humain crée une cible sans en-tête | OK | OK | OK |
| un humain pose le label `link` sur ce CR | refus | refus (par erreur d'évaluation) | refus |
| un humain pose seulement l'annotation `link.weebo.io/source` | refus | **OK** | refus |
| un humain supprime une cible liée | OK | OK | OK |

`link-headers`, telle qu'écrite ci-dessus, passe ses 7 cas : sans
annotation, `enabled`, valeur `"true"` refusée, en-tête inconnu refusé,
autres annotations, status écrit par weebo-authentik, retrait de l'en-tête.

Conséquence pour l'importer : il est accepté sur une cible liée tant qu'il
réapplique **la même spec**. Avec une spec différente, il est refusé. Pour
importer un compte JIT sous une cible liée, on passe la VAP en `Audit` le
temps de l'import (*Exploitation*).

**Q1.** Un binaire de test sur `cel` 0.15, puis sur `kube-cel` 0.8 / `cel`
0.13, appliqué aux expressions de la règle et à des objets JSON réalistes :

- **Mapping et `safe` :** le mapping (`metadata.name`, `spec.username`,
  le ternaire sur `isActive`, une annotation à clé avec points) et `safe`
  donnent les valeurs attendues. `safe` est faux si `observedGeneration`
  est en retard.
- **Macros :** `all`, `exists` sur les clés d'une map, `filter().map()` et
  `has()` fonctionnent.
- **`substring` :** absent du cœur de `cel`, présent avec
  `Context::default().with_all()` de `kube-cel`.
- **Erreurs :** une erreur de syntaxe donne la position et ce qui était
  attendu. Un champ absent donne « No such key: … », une variable inconnue
  « Undeclared reference ». D'où la règle « erreur ≠ vrai » et le `has()`
  dans `safe`.
- **Piège des entiers :** avec la conversion serde par défaut de `cel`
  0.13, un entier JSON positif devient `uint`, et `generation == 3` vaut
  `false` sans erreur, alors que `>` fonctionne. Avec `json_to_cel`
  (entiers en `int`, comme l'apiserver), c'est `true`. Entre deux champs
  JSON, l'égalité marche dans les deux cas.

## Travaux futurs

- **D'autres paires**, une fois leurs CRD prêts : `AuthentikGroup` →
  `StalwartGroup` (sans état sûr, `then: Delete`), `AuthentikUser` →
  `ForgejoUser` (pré-création avant le premier login OAuth), puis Che et
  BatleHub. Chacune avec son contrat de cible.
- **Un CRD `Link` namespacé** (alternative 2), si des équipes doivent
  définir leurs propres liens dans leur namespace.
- **Le contrôleur dynamique versé au kit** (`weebo-kit-runtime`), si un
  second composant en a l'usage.

## Plan d'implémentation

Chaque case est une PR qu'on peut merger seule.

**Spike (avant `Accepted`)**

- [x] Choix de la crate CEL (Q1) ; VAP `link-targets` contre les
      écritures de l'opérateur, des humains et de l'importer (Q2) ; version
      du cluster (Q3). Voir *Vérifications*.

**Phase 1 — weebo-link v0.1.0**

- [ ] Dépôt sur les crates runtime du kit v0.17.0 (lease, santé, OTLP,
      métriques, Events), `cog.toml`, `checks.yml`/`publish.yml`, chart sur
      `weebo-operator-lib`
- [ ] Règles : chargement, validation par discovery, compilation CEL,
      rechargement à chaud, `check-rules`
- [ ] Apply des cibles (SSA, fieldManager par lien), `immutable`,
      `TargetExists`
- [ ] Départ : `onRemoval`, `safe`, `Detaching`/`Detached`, resync des
      cibles orphelines, rattachement
- [ ] VAP `link-headers` et `link-targets` rendues par le chart depuis les
      règles
- [ ] envtest sur CRD factices : création, mise à jour, départ, départ
      pendant une panne, source recréée (UID), faux label refusé

**Phase 2 — weebo-si, premier lien (après weebo-stalwart v0.2.0, RFC 0001)**

- [ ] `auth/sub` : `links` rendu en en-têtes dans `users.yaml`
- [ ] `2.argo/helm/link` : Application, règle
      `authentik-user-stalwart-account`, VAP en `Audit`
- [ ] Un utilisateur de test, scénario de bout en bout, VAP en `Deny`
- [ ] Tous les utilisateurs avec boîte en `links: [stalwart]` ; panneau et
      alertes « Liens »

**Clôture**

- [ ] RFC 0001 et left-todo à jour, doc de weebo-link
      (`@weebo/operator-docs`), RFC passée en `Implemented`

## Références

- [ValidatingAdmissionPolicy](https://kubernetes.io/docs/reference/access-authn-authz/validating-admission-policy/)
- [CEL dans Kubernetes](https://kubernetes.io/docs/reference/using-api/cel/)
- [Server-side apply et field managers](https://kubernetes.io/docs/reference/using-api/server-side-apply/)
- weebo-operator-kit v0.17.0 : `crates/weebo-kit-runtime` (`leader.rs`,
  `health.rs`, `telemetry.rs`, `metrics.rs`, `events.rs` ; `controller.rs`
  et `scope.rs` typés), `docs/plan.md` (« Ce qui va dans le kit », règle
  des deux opérateurs, jamais d'adoption par nom)
- weebo-si : `2.argo/helm/hook/sub/templates/mount-cert.yaml` (convention
  d'opt-in par annotation), `2.argo/helm/auth/sub/templates/identity/users.yaml`
- [RFC 0001](/docs/rfc/0001-stalwart) : D7, D8, D9, *Ce que la brique de liaison consomme*, *Verrouillage*

## Changelog

| Date | Changement |
| --- | --- |
| 2026-10-18 | Brouillon initial (Kyverno `generate` + garde de départ) |
| 2026-10-18 | Kyverno abandonné, car la brique `hook` peut disparaître : contrôleur `weebo-link` sans CRD (règles dans ses values), départ en un commit par patch vers l'état sûr et cible gardée `Detached`, hooks en `ValidatingAdmissionPolicy` natives |
| 2026-10-18 | Q1–Q3 tranchées (*Vérifications*) : `kube-cel` 0.8 et sa conversion JSON en `int` ; `link-targets` réécrite pour ne comparer que la spec et les en-têtes `link.weebo.io/*` (18/18 scénarios sur un kube-apiserver v1.36.2) ; `has(target.status)` dans `safe`, et une évaluation en erreur ne vaut jamais vrai |
