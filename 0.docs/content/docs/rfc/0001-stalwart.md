---
title: "RFC 0001 — Stalwart et weebo-stalwart"
description: "Une messagerie interne au cluster, et l'opérateur qui en gère les objets, credentials dans Vault"
rfc: 0001
status: Draft
authors: [batleforc]
created: 2026-10-18
updated: 2026-10-18
decided:
brick: 2.argo/helm/mail, github.com/batleforc/weebo-stalwart
supersedes: []
superseded-by: []
---

# RFC 0001 — Stalwart, messagerie interne, et l'opérateur weebo-stalwart

- **Dépôts :** weebo-si (déploiement), `weebo-stalwart` (nouvel opérateur)
- **Base :** weebo-operator-kit v0.17.0, Stalwart v0.16.x, weebo-authentik 0.18.1, OpenBao (`mv`)
- **Ligne de left-todo :** « Setup Stalwart as an internal mail system for the cluster… »

## Résumé

On déploie [Stalwart](https://stalw.art/) v0.16 dans le namespace `mail`
comme seul serveur mail du domaine interne `weebo.poc` : les apps du cluster
y soumettent leurs mails, les utilisateurs Authentik y ont une boîte, et rien
ne sort du cluster. Un nouvel opérateur, `weebo-stalwart`, généré depuis le
template de weebo-operator-kit, porte le cycle de vie de ce qui vit dans
Stalwart :

- le domaine ;
- les comptes d'envoi des apps, avec leurs credentials publiés dans Vault ;
- les boîtes des utilisateurs (`StalwartAccount`), créées et verrouillées
  par CR ;
- les groupes, les listes et les App Passwords.

C'est le même contrat que weebo-forgejo : CR déclaratifs, `Ready` dans
`status.conditions`, `secretTargets`, allow-list par namespace.

L'opérateur ne connaît que Stalwart. **Le lien avec Authentik** (un
`AuthentikUser` donne un `StalwartAccount`, son retrait le verrouille) est
le rôle d'une **autre brique**, qui lie les opérateurs entre eux :
[RFC 0002](/docs/rfc/0002-liaison), par en-têtes `link.weebo.io`, un petit
contrôleur `weebo-link` et des `ValidatingAdmissionPolicy`. Celle-ci ne fixe que le contrat que cette brique
consomme : les CR `stalwart.weebo.io`.

Cette RFC concerne quiconque opère weebo-si, ajoute une app qui envoie du
mail, ou écrit un opérateur sur le kit.

## Motivation

### Aujourd'hui

- **Aucune app n'envoie de mail.** Authentik (récupération de compte,
  enrollment), Forgejo (notifications, reset), les notifications Argo CD et
  les alertes de monitoring n'ont aucune config SMTP. Un grep `smtp|mailer`
  sur `2.argo`, `2.helm` et `2.terra` ne renvoie rien. Les adresses en
  `@weebo.poc` qui existent (`forgejo-admin@weebo.poc`, les emails des
  `AuthentikUser`) ne mènent nulle part.
- **Les brancher sur un SMTP externe** (Gmail, un relais OVH) ferait sortir
  du cluster des mails qui contiennent des liens de reset et des jetons
  d'invitation, vers une infra qu'on ne contrôle pas. C'est contraire à
  l'objectif de weebo-si, où tout le cycle dev reste interne.
- **Stalwart seul ne suffit pas.** Sa directory OIDC (contre Authentik)
  authentifie les utilisateurs, mais la
  [doc](https://stalw.art/docs/auth/backend/oidc/) en donne elle-même les
  limites :
  1. *Pas de compte avant le premier login.* Un compte n'existe qu'après une
     première authentification (JIT). D'ici là, un mail vers
     `alice@weebo.poc` est rejeté, faute de destinataire local.
  2. *Pas de déprovisioning.* Un utilisateur supprimé ou désactivé dans
     Authentik garde sa boîte, qui continue de recevoir.
  3. *Clients lourds.* Thunderbird, Apple Mail et Outlook ne font pas
     OAUTHBEARER avec un IdP tiers. La réponse documentée est l'App Password,
     que quelqu'un doit créer et remettre à l'utilisateur.

  Les deux premiers points ont une réponse officielle, SCIM, mais elle est
  réservée à l'édition Enterprise. Aucun des trois ne couvre les comptes
  d'envoi des apps.

### Une fois en place

- Chaque app qui envoie du mail a un compte d'envoi dédié. Ses credentials
  sont dans `mv/<app>/smtp`, où son ExternalSecret les lit, sans copier-coller.
- Un `StalwartAccount` donne une boîte qui reçoit dès sa création, sans
  attendre un premier login. Passé en `state: Locked`, la boîte n'accepte
  plus ni login ni réception. Qui crée et verrouille ces CR (à la main, ou la
  brique de liaison depuis Authentik) n'est pas l'affaire de l'opérateur.
- Une CiliumNetworkPolicy garantit qu'aucun pod de `mail` ne joint
  l'extérieur, quelle que soit la config de Stalwart.
- Chaque objet a un état lisible : `kubectl get stalwartserviceaccounts -A`
  donne `Ready` et la raison, comme pour forgejo.

C'est ce qu'on vérifiera au passage en `Implemented`.

### Objectifs et non-objectifs

| Objectif | Non-objectif |
| --- | --- |
| Mail interne `weebo.poc`, app → user et user ↔ user | Recevoir du mail d'Internet (MX public) |
| Comptes d'envoi des apps, credentials dans Vault | Envoyer vers Internet (relais sortant) |
| Boîtes des users (`StalwartAccount`), création et verrouillage | Webmail tiers (Roundcube, SnappyMail…) |
| Opérateur sur le kit, conventions des autres opérateurs | Déployer Stalwart depuis l'opérateur (mode *managed*) |
| Un seul nœud, une réplique | Cluster Stalwart multi-nœuds |
| Un contrat CR stable, consommable par la brique de liaison | Lire les CR d'un autre opérateur (`AuthentikUser`…) : c'est la brique de liaison |

## Explication pour l'exploitant

### Ce qui est installé

L'Application Argo `mail`, nouveau chart `2.argo/helm/mail`, dans le même
ordre de waves que forgejo :

| Wave | Objet | Rôle |
| --- | --- | --- |
| 0 | SecretStore `cred-store`, ExternalSecrets | `mv/mail/{pg,s3,admin,auth}` vers des Secrets du namespace `mail` |
| 1 | Cluster CNPG `stalwart`, Certificate `stalwart-tls` | datastore, TLS des listeners (CA interne) |
| 2 | StatefulSet `stalwart`, Services, IngressRoute, CiliumNetworkPolicy | le serveur |
| 2 | Job PostSync `stalwart-bootstrap` | crée le compte et l'ApiKey de l'opérateur (une seule fois) |
| 3 | Application `weebo-stalwart` | l'opérateur, dans le namespace `weebo-stalwart` |
| 4 | `StalwartInstance` `default`, `StalwartNamespacePolicy` `weebo-allow` | connexion et allow-list |
| 5 | `StalwartDomain` `weebo.poc` (cluster) | le domaine |

Les comptes d'envoi sont déclarés **dans le chart de chaque app**, à côté de
son ExternalSecret, comme les `AuthentikApplication` aujourd'hui.

### Brancher une app (exemple : Forgejo)

```yaml
# 2.argo/helm/forgejo/templates/mail/service-account.yaml
apiVersion: stalwart.weebo.io/v1alpha1
kind: StalwartServiceAccount
metadata:
  name: forgejo
  namespace: forgejo
  annotations:
    argocd.argoproj.io/sync-wave: "5"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  domainRef: { name: weebo.poc }   # StalwartDomain cluster-scoped
  name: forgejo                 # forgejo@weebo.poc
  aliases: [noreply]            # noreply@weebo.poc, utilisable en From
  receive: false
  secretTargets:
    - backend: vault
      name: smtp                # mv/forgejo/smtp
```

`mv/forgejo/smtp` contient alors :

| Clé | Valeur |
| --- | --- |
| `host` | `stalwart.mail.svc.cluster.local` |
| `port` | `587` |
| `security` | `starttls` |
| `username` | `forgejo@weebo.poc` |
| `password` | 32 caractères générés par l'opérateur |
| `from` | `noreply@weebo.poc` (le premier alias, sinon l'adresse) |

L'ExternalSecret de forgejo les injecte dans `[mailer]`.

```console
$ kubectl -n forgejo get stalwartserviceaccount
NAME      ADDRESS             READY   REASON        AGE
forgejo   forgejo@weebo.poc   True    Reconciled    3m
```

Et quand ça ne marche pas :

```console
$ kubectl -n batlehub get stalwartserviceaccount
NAME       ADDRESS              READY   REASON               AGE
batlehub   batlehub@weebo.poc   False   NamespaceNotAllowed  10s
```

L'admission l'aurait déjà refusé, avec le même message. Le reconciler
revérifie pour le cas où le webhook a été contourné.

### Donner une boîte à un utilisateur

Un `StalwartAccount` dans `mail`. En régime normal, c'est la brique de
liaison qui le pose depuis l'`AuthentikUser` ; en attendant, ou pour un cas
isolé, on le déclare à la main :

```yaml
apiVersion: stalwart.weebo.io/v1alpha1
kind: StalwartAccount
metadata:
  name: alice
  namespace: mail
spec:
  domainRef: { name: weebo.poc }
  name: alice                  # = preferred_username Authentik (Q3)
  quota: 2Gi
```

La boîte reçoit immédiatement. Alice se
connecte à la WebUI (`https://mail.weebo.poc`) par Authentik. Pour
Thunderbird, elle demande un App Password :

```yaml
apiVersion: stalwart.weebo.io/v1alpha1
kind: StalwartAppPassword
metadata:
  name: alice-thunderbird
  namespace: mail
spec:
  accountRef: { name: alice }
  description: Thunderbird portable
  expiresIn: 2160h                       # 90 jours
  secretTargets:
    - backend: vault
      name: alice-thunderbird       # mv/mail/alice-thunderbird (pathPrefix "")
```

Quand Alice part, son `StalwartAccount` passe en `state: Locked` (voir
*Verrouillage*), par la brique de liaison ou à la main, et la boîte reste
sur disque jusqu'à un `Delete` explicite.

## Design

### Compatibilité avec weebo-operator-kit

Règle de cette RFC : **rien n'est réinventé à côté du kit**. Le dépôt est
généré par `cargo generate --git https://github.com/batleforc/weebo-operator-kit --tag v0.17.0 templates/operator`
(`product = Stalwart`, d'où le groupe `stalwart.weebo.io`). Il garde le
découpage, les noms et les comportements du template. Ce qui est propre à
Stalwart se limite à ce que le kit laisse explicitement à chaque opérateur
(`docs/plan.md`, « Ce qui va dans le kit ») :

- les `#[derive(CustomResource)]` ;
- le catalogue `ReasonCode` ;
- les gateways et leurs ports ;
- les use-cases `reconcile_*` ;
- la factory qui lit l'instance ;
- les valeurs par défaut du schéma (`pathPrefix`).

| Convention du kit | Application ici |
| --- | --- |
| `StalwartInstance` (cluster) + `StalwartLocalInstance` (namespacé, `sharedWith`, jeton labellé `instance-token`) | Les deux sont gardées telles que le template les génère. Résolution par l'`InstanceDirectory` du kit : `instanceRef` omis = l'unique `StalwartInstance`, sinon l'unique `StalwartLocalInstance` du namespace. |
| `InstanceRef {name, kind, namespace}` et `status.instance` (`BoundInstance`) | Sur chaque kind lié à une instance. Un objet ne change jamais d'instance en silence (`InstanceBindingChanged`). |
| `ObjectRef {name}` : même namespace pour une cible namespacée, cluster-wide pour une cible cluster-scoped | Pas de référence cross-namespace : `StalwartDomain` est **cluster-scoped** (un domaine est une infra d'organisation, comme une instance), et tout le reste se référence dans son namespace. |
| `*NamespacePolicy` cluster-scoped, moteur `allow_list` (namespaces × kinds × dimensions, `Allow`/`Deny`, deny-by-default dès qu'une policy existe) | `StalwartNamespacePolicy`, avec deux dimensions : `domains` (noms des `StalwartDomain`) et `names` (local-parts Stalwart résolus, comme `allowedUsers` chez forgejo). |
| `SecretTarget` / `secretTargets`, cible implicite nommée d'après le CR, `emit::write_all`, `any_missing`, check-and-set Vault, owner sur chaque chemin | Comptes d'envoi et App Passwords. Aucun chemin hors de `<pathPrefix>/<namespace>/` : `pathGrants` n'est pas nécessaire. |
| `secretStore {backend, vault {address, mount, pathPrefix, kubernetesAuthRole, kubernetesAuthMount, caSecretRef, pathGrants}}` sur l'instance | Repris tel quel. `pathPrefix` vaut `weebo-stalwart` par défaut, et weebo-si pose `""` pour écrire `mv/<namespace>/<name>`. |
| `TlsOptions` / `LocalTlsOptions` | `spec.tls` des deux instances. |
| Annotations `<domaine>/force-orphan`, `allow-disruptive-update`, `rotate-secret` (nonce), `import-pending`, `previous-owner` ; label `instance-token` | Toutes, sous `stalwart.weebo.io/`, avec la sémantique du kit. Aucune annotation de comportement en plus. |
| `status` : `observedGeneration`, `remoteId` (sa présence = ce CR possède l'objet distant), `instance`, `conditions` (`Ready`) | Un `Status` commun à tous les kinds, plus deux champs optionnels : `address` et `lastRotation` (le nonce consommé, lu par `emit::rotation_requested`). |
| Colonnes `Instance` / `URL`, `Ready`, `Reason` | Les mêmes, plus `Address` sur les kinds de compte. |
| Jamais d'adoption par nom : un nom pris échoue (`…AlreadyExists`) ; reprise d'un objet existant uniquement par l'importer (`import-pending`) et après la garde de revendication unique (`RemoteObjectClaimed`) | Repris tel quel : `StalwartObjectAlreadyExists`, `RemoteObjectClaimed`, un importer `weebo-stalwart-importer` (crate `importer`, comme forgejo). Les comptes créés par la JIT OIDC passent par le même chemin d'import. |
| Finalizer, `deletionPolicy: Delete \| Orphan` | Sur tous les kinds distants. Le verrouillage est un **état** (`spec.state`), pas une politique de suppression. |
| Runtime : leader election (Lease), `WatchScope` (cluster, sélecteur de labels ou un namespace), health, OTLP, `ReconcileMetrics`, `Admission` + `check_vault_targets` + `ScopeGuard` | Utilisés sans surcouche. |
| Chart `weebo-operator-lib`, `tasks/*.yaml`, `checks.yml` / `publish.yml`, `cog.toml` du kit, `@weebo/operator-docs`, `weebo-kit-perf` | Le dépôt les consomme par tag, comme forgejo. Chart publié en `oci://ghcr.io/batleforc/charts/weebo-stalwart`. |

Deux sujets touchent la frontière avec le kit, sans le modifier :

- **Aucun CRD d'un autre opérateur n'est lu.** Comme chaque opérateur du
  kit, weebo-stalwart ne watche que ses propres kinds (et les Secrets de
  ses instances et cibles). Le lien Authentik → Stalwart appartient à la
  brique de liaison (D7), qui n'écrit que des CR `stalwart.weebo.io` et
  passe donc par le même webhook et la même allow-list que n'importe quel
  client.
- **Le socle « workload géré » (v0.17)** n'est pas utilisé en v1 (D1). Le
  jour du mode *managed*, il est consommé tel quel, comme batlehub.

Si le spike montre qu'un besoin n'entre dans aucun de ces mécanismes,
l'opérateur ne le contourne pas : on ajoute la pièce au kit d'abord (règle
des deux opérateurs), par une RFC du kit.

### Décisions

| # | Décision | Pourquoi |
| --- | --- | --- |
| D1 | Stalwart déployé par weebo-si (chart maison), opérateur sur un serveur existant | Le chart de la doc Stalwart n'est pas publié, c'est un exemple. Le vendoriser coûte quatre templates. Le mode *managed* reste ouvert (*Travaux futurs*). |
| D2 | Template du kit sans retrait : `StalwartInstance` et `StalwartLocalInstance` | `InstanceKind` du kit connaît les deux, et l'`InstanceDirectory` résout les deux. Retirer la locale ferait diverger le schéma de `instanceRef`. weebo-si n'utilise que la cluster. |
| D3 | `StalwartDomain` cluster-scoped | `ObjectRef` du kit ne traverse pas les namespaces. Un domaine partagé par toutes les apps doit donc être cluster-scoped, et c'est ce qui en fait une dimension de l'allow-list. |
| D4 | Client JMAP écrit à la main | Huit types `x:*`, trois méthodes chacun. Il est validé par un test de contrat contre l'image. |
| D5 | L'opérateur ne possède que les champs qu'il écrit | La JIT OIDC de Stalwart écrit aussi sur `x:Account` (`description`, `memberGroupIds`). |
| D6 | Les groupes d'un user viennent d'OIDC (`claimGroups`) | Conséquence de D5. |
| D7 | Le lien Authentik → Stalwart est hors de l'opérateur, dans une autre brique | Un opérateur par produit : weebo-stalwart ne lit aucun CRD `authentik.weebo.io`, et weebo-authentik n'écrit rien chez Stalwart. La brique de liaison, commune à tous les opérateurs, traduit un objet d'un produit en CR d'un autre. Elle a sa propre RFC. |
| D8 | Départ d'un user = `state: Locked`, jamais une suppression | Un retrait par erreur ne détruit pas de mail. `deletionPolicy` garde la sémantique du kit. C'est la consigne donnée à la brique de liaison. |
| D9 | Un compte JIT existant n'est repris que par import | Le kit n'adopte jamais par nom. Un `StalwartAccount` dont le nom est déjà pris échoue en `StalwartObjectAlreadyExists`, quel que soit son auteur, et l'importer le relie après la garde de revendication unique. |
| D10 | `tokenSecretRef` = ApiKey Bearer, à permissions `Replace` minimales | C'est le contrat d'instance du kit (un jeton dans un Secret, relu à chaque appel). Si le spike invalide le Bearer (Q1), le Secret contient `user:password` et seule la gateway change, pas le CRD. |
| D11 | DataStore PostgreSQL (CNPG), BlobStore S3 (RustFS) | Ça reprend les sauvegardes existantes et laisse le StatefulSet jetable. |
| D12 | Egress de `mail` coupé au niveau Cilium | « Rien ne sort » ne dépend pas de la config Stalwart. |

### Contrat

Groupe `stalwart.weebo.io`, version `v1alpha1`. Tous les kinds ont :

- le `Status` commun (`observedGeneration`, `remoteId`, `instance`,
  `conditions`, et selon le kind `address`, `lastRotation`) ;
- les colonnes `Ready` et `Reason` ;
- le finalizer du runtime ;
- les annotations du kit sous `stalwart.weebo.io/`.

`instanceRef` est l'`InstanceRef` du kit, à la même sémantique que dans le
template.

#### `StalwartInstance` (cluster) et `StalwartLocalInstance` (namespacé)

Ce sont les specs du template, avec les champs que forgejo y ajoute.

| Champ | Type (kit) | Défaut | Rôle |
| --- | --- | --- | --- |
| `url` | string | — | Base HTTP de Stalwart. L'API JMAP est sous `/api`. |
| `tokenSecretRef` | `SecretKeyRef` (locale : `LocalSecretKeyRef` + label `instance-token`) | — | ApiKey, relue à chaque appel |
| `sharedWith` | `SharedWith` | — | locale seulement, comme le template |
| `tls` | `TlsOptions` (locale : `LocalTlsOptions`) | — | `caSecretRef`, `insecureSkipVerify` |
| `secretStore` | `{backend: SecretStoreBackend, vault: {…, pathGrants: []VaultPathGrant}}` | `kubernetes`, `pathPrefix: weebo-stalwart` | backend par défaut des `secretTargets` |
| `submission` | `{host, port, security}` | `stalwart.mail.svc.cluster.local`, `587`, `starttls` | Spécifique à Stalwart : ce que les credentials publiés annoncent |

La plage de versions supportées est une constante de l'opérateur, comme
`UnsupportedForgejoVersion`, et pas un champ. `ping` lit la version
et refuse en dehors.

#### `StalwartNamespacePolicy` (cluster)

La forme de `ForgejoNamespacePolicy`, évaluée par le moteur `allow_list`
du kit :

```yaml
apiVersion: stalwart.weebo.io/v1alpha1
kind: StalwartNamespacePolicy
metadata:
  name: weebo-allow
spec:
  rules:
    - namespaces: [mail]
      allowedKinds: [StalwartAccount, StalwartGroup, StalwartMailingList,
                     StalwartAppPassword]
    - namespaces: [forgejo, auth, argocd]
      allowedKinds: [StalwartServiceAccount]
      allowedDomains: [weebo.poc]        # dimension "domains"
    - effect: Deny                        # noms réservés, quel que soit le namespace
      namespaces: ["*"]
      allowedKinds: [StalwartServiceAccount]
      allowedNames: [postmaster, abuse, admin, root, noreply]   # dimension "names"
```

Seuls les kinds namespacés liés à une instance cluster sont gouvernés.
`StalwartDomain`, les instances et la policy restent sous RBAC (Argo CD),
comme chez forgejo.

#### `StalwartDomain` (cluster) → `x:Domain`

| Champ | Type | Défaut | Champ Stalwart |
| --- | --- | --- | --- |
| `instanceRef` | `InstanceRef` | l'unique instance | — |
| `name` | DomainName | `metadata.name` | `name` |
| `aliases` | []DomainName | `[]` | `aliases` |
| `catchAll` | string? | — | `catchAllAddress` (local-part) |
| `subAddressing` | bool | `true` | `subAddressing` |
| `dkim` | `Automatic` \| `Disabled` | `Automatic` | `dkimManagement` |
| `deletionPolicy` | `Delete` \| `Orphan` | `Orphan` | — |

L'opérateur pose aussi `certificateManagement: Manual`,
`dnsManagement: Manual` et `allowRelaying: false`, qui ne sont pas exposés.
Changer `name` est une mise à jour disruptive : il faut
`allow-disruptive-update: "true"`.

#### `StalwartServiceAccount` (namespacé) → `x:Account` `@type: User` + credential `Password`

| Champ | Type | Défaut | Rôle |
| --- | --- | --- | --- |
| `instanceRef` | `InstanceRef` | — | |
| `domainRef` | `ObjectRef` (cluster-scoped) | — | le `StalwartDomain` |
| `name` | EmailLocalPart | `metadata.name` | `name` (dimension `names`) |
| `aliases` | []EmailLocalPart | `[]` | `aliases`, dans le même domaine, vérifiés aussi par `names` |
| `receive` | bool | `false` | `false` : `emailReceive` désactivé |
| `secretTargets` | []`SecretTarget` | cible implicite du kit | clés `host`, `port`, `security`, `username`, `password`, `from` |
| `deletionPolicy` | `Delete` \| `Orphan` | `Delete` | |

L'opérateur génère le mot de passe à la création, le pose comme credential
`Password` et l'écrit par `emit::write_all`. Il le régénère sur un nouveau
nonce `rotate-secret` (`emit::rotation_requested` contre
`status.lastRotation`), ou quand `emit::any_missing` détecte une cible qui
l'a perdu. Les permissions `imapAuthenticate`, `pop3Authenticate` et
`sieveAuthenticate` sont désactivées, ainsi que `emailReceive` si
`receive: false`.

#### `StalwartAccount` (namespacé) → `x:Account` `@type: User`

| Champ | Type | Défaut | Rôle |
| --- | --- | --- | --- |
| `instanceRef` | `InstanceRef` | — | |
| `domainRef` | `ObjectRef` (cluster-scoped) | — | |
| `name` | EmailLocalPart | `metadata.name` | doit égaler le `preferred_username` Authentik (Q3) |
| `aliases` | []EmailLocalPart | `[]` | |
| `quota` | Quantity? | — | `quotas` |
| `locale`, `timeZone` | string? | — | |
| `state` | `Active` \| `Locked` | `Active` | voir *Verrouillage* |
| `deletionPolicy` | `Delete` \| `Orphan` | `Orphan` | une boîte humaine ne se supprime qu'explicitement |

Pas de credential : l'authentification passe par OIDC, et les App Passwords
par leur kind. Pas de `memberGroupIds` (D6).

#### `StalwartGroup` (namespacé) → `x:Account` `@type: Group`

Champs `instanceRef`, `domainRef`, `name`, `aliases`, `quota` et
`deletionPolicy` (`Orphan` par défaut). `name` égale le nom du groupe
Authentik publié dans le claim `groups`.

#### `StalwartMailingList` (namespacé) → `x:MailingList`

Champs `instanceRef`, `domainRef`, `name`, `aliases`, `deletionPolicy` et
`recipients`. `recipients` est une liste de `{address}` ou de `{accountRef}`,
où `accountRef` est un `ObjectRef` vers un `StalwartAccount` du même
namespace.

#### `StalwartAppPassword` (namespacé) → `x:AppPassword`

| Champ | Type | Rôle |
| --- | --- | --- |
| `accountRef` | `ObjectRef` vers un `StalwartAccount` du même namespace | propriétaire (l'instance est la sienne) |
| `description` | string | |
| `expiresIn` | Duration? | `expiresAt` calculé à la création |
| `allowedIps` | []CIDR | |
| `secretTargets` | []`SecretTarget` | clés `username`, `password`, `imapHost`, `submissionHost` |
| `deletionPolicy` | `Delete` \| `Orphan` | `Delete` |

C'est le cas d'usage d'`emit` : une valeur que le système distant ne montre
qu'une fois. Une cible qui l'a perdue (`any_missing`) impose une rotation
(nouvel `x:AppPassword`, l'ancien détruit), et un nonce `rotate-secret`
aussi. Un compte `Locked` passe ses App Passwords en `Ready: False`
`AccountLocked` et les détruit côté Stalwart.

#### Ce que la brique de liaison consomme

L'opérateur n'a aucun kind « source » : la brique de liaison écrit des
`StalwartAccount` (et au besoin des `StalwartGroup`) comme le ferait un
humain dans Git. Ce que cette RFC lui garantit, et ce qu'elle attend d'elle :

- **Écriture :** des `StalwartAccount` dans un namespace autorisé par la
  `StalwartNamespacePolicy` (`mail` dans weebo-si). Elle passe par le
  webhook et l'allow-list comme tout client ; elle n'a aucun droit sur
  Stalwart lui-même.
- **Identité :** `spec.name` égale le `preferred_username` Authentik, pour
  que la JIT OIDC retombe sur le même compte (Q3). Changer `spec.name` est
  une mise à jour disruptive : la brique crée un nouveau CR plutôt que de
  renommer.
- **Départ :** `spec.state: Locked`, pas une suppression (D8). Une
  suppression applique la `deletionPolicy` du CR, `Orphan` par défaut.
- **Lecture :** `status.conditions` (`Ready`, raison) et `status.address`,
  pour qu'elle reporte l'état côté source si elle le souhaite.
- **Compte JIT déjà présent :** le CR échoue en
  `StalwartObjectAlreadyExists`. La reprise passe par
  `weebo-stalwart-importer` (`import-pending`, garde `RemoteObjectClaimed`) ;
  l'opérateur n'adopte jamais par nom (D9). Que la brique pose elle-même
  `import-pending` est une question de sa RFC.

La RFC 0002 en tire l'**état sûr** de `StalwartAccount` : `state: Locked`
et `Ready` à jour. Au départ d'un utilisateur lié, weebo-link patche la
cible vers cet état et la garde (`Detached`) au lieu de la supprimer.

Tant que la brique n'existe pas, ces CR se déclarent à la main dans
`2.argo/helm/mail`.

#### Verrouillage

Le schéma `Account` de v0.16 n'a pas de champ `disabled`. `state: Locked`
fait trois choses :

1. désactive `authenticate`, `emailSend` et `emailReceive` dans
   `permissions` (Q4) ;
2. détruit les `x:AppPassword` du compte ;
3. garde les mails, l'adresse et les alias, pour qu'aucun autre CR ne
   puisse les reprendre : la revendication de `remoteId` reste.

`Active` retire les désactivations. Les App Passwords ne sont pas recréés.

#### Codes de raison (`reason_codes!`)

Ceux du template, inchangés : `Reconciled`, `InstanceNotFound`,
`InstanceAmbiguous`, `InstanceNotAllowed`, `InstanceBindingChanged`,
`TokenSecretMissing`, `TokenSecretNotAllowed`, `InvalidSpec`,
`InstanceUnreachable`, `InstanceUnauthorized`, `RemoteError`,
`KubernetesApiError`, `Created`, `Deleted`, `Released` et
`LeavesWatchScope`.

Ceux qui reprennent le nom déjà utilisé par forgejo : `NamespaceNotAllowed`,
`SecretTargetFailed`, `RemoteObjectClaimed`,
`StalwartObjectAlreadyExists` (comme `ForgejoObjectAlreadyExists`) et
`UnsupportedStalwartVersion`.

Ceux qui sont propres à Stalwart : `DomainNotFound`, `DomainNotReady`,
`AccountNotFound`, `AccountLocked` et `ObjectIsLinked` (suppression refusée
par le serveur).

`Created`, `Deleted`, `Released` et `Reconciled` sont des avis
(`Severity::Advisory`). Tout le reste bloque.

#### Webhook

Ce sont l'`Admission` et le `router` du runtime, en `failurePolicy: Fail` sur
les seuls kinds `stalwart.weebo.io`. Contrôles :

- l'allow-list (`allow_list::evaluate`, dimensions `domains` et `names`) ;
- `check_vault_targets` ;
- le `ScopeGuard` (`LeavesWatchScope`) ;
- les alias restent dans le domaine du compte ;
- l'unicité `domainRef + name` entre CR, par l'index du reflector, en plus
  de la revendication unique au reconcile.

#### Métriques

`ReconcileMetrics` du kit, avec le préfixe `weebo_stalwart`. En plus :

- `weebo_stalwart_accounts{state}` ;
- `weebo_stalwart_api_requests_total{method,outcome}`.

La page de référence des métriques et des codes vient de `@weebo/operator-docs`.

### Architecture

La réponse est **oui, hexagonale**, avec les crates du template, renommées
par `cargo generate` :

| Crate | Contenu propre à Stalwart |
| --- | --- |
| `domain` | `ReasonCode` ; règles pures (adresse, alias dans le domaine, permissions désactivées pour un état) |
| `api` | les CRD, sur les types de `weebo-kit-api` |
| `application` | `RemoteGateway` étendu par kind (`ping`, `ensure_*`, `delete_*`, `find_*`), `GatewayFactory` ; use-cases `reconcile_instance`, `reconcile_domain`, `reconcile_service_account`, `reconcile_account`, `reconcile_group`, `reconcile_mailing_list`, `reconcile_app_password` |
| `adapters-outbound` | `JmapGateway` (à la place de `http_gateway.rs`), `gateway_factory.rs` du template (token relu à chaque appel, `SecretStoreFactory` du kit) |
| `adapters-inbound` | controllers et webhook du template, rien hors de `stalwart.weebo.io` |
| `importer` | `weebo-stalwart-importer` : relie un objet Stalwart existant à un CR (`import-pending`) |
| `crdgen`, `operator`, `testkit` | ceux du template ; le testkit ajoute un Stalwart v0.16 en conteneur pour les tests de contrat |

**Réconciliation d'un compte**, sur le modèle de `reconcile_object` du
template :

1. Résoudre l'instance (`InstanceDirectory`, `status.instance`) et le
   domaine. Si le domaine n'est pas `Ready`, `DomainNotReady`.
2. Évaluer la policy (même verdict que le webhook).
3. Sans `status.remoteId` : vérifier qu'aucun autre CR ne revendique le
   nom, puis `x:Account/set create`. Un nom déjà pris côté Stalwart donne
   `StalwartObjectAlreadyExists` : on n'adopte jamais. Avec `remoteId` :
   `x:Account/get`, puis un patch des seuls champs possédés.
4. Secrets : `emit::check_targets`, puis `write_all` à la création, sur un
   nouveau nonce de rotation ou si `any_missing`.
5. Status, condition, Event.

La suppression suit le finalizer du runtime : `force-orphan` libère sans
rien toucher, `deletionPolicy: Orphan` libère en laissant l'objet distant,
et `Delete` détruit l'objet distant et appelle `emit::delete_all`.
`objectIsLinked` donne `ObjectIsLinked`, et l'opérateur requeue sans forcer.

### Données et état

L'opérateur est **sans état**. La vérité est dans les CR, dans Stalwart et
dans le `SecretStore`.

- **`status.remoteId` perdu** (status effacé) : le CR retombe en création
  et échoue en `StalwartObjectAlreadyExists`. La reprise passe par
  l'importer, comme chez forgejo. Une migration qui déplace un CR pose
  `previous-owner` pour qu'il retrouve ses secrets.
- **Mots de passe des comptes d'envoi :** écrits par `emit`, jamais relus
  côté Stalwart. Si la cible les perd, `any_missing` déclenche une rotation.
- **Stalwart repart d'une base vide :** les `remoteId` ne résolvent plus
  (`x:*/get` vide), et le CR est recréé côté Stalwart. Les mails sont
  perdus, les mots de passe sont régénérés et republiés.

### Déploiement de Stalwart dans weebo-si

- **Image :** `stalwartlabs/stalwart:v0.16.x`, épinglée par Renovate. Le
  namespace `mail` est hors Che, mais on tire quand même par angos si
  `imagePolicy` est étendu un jour (Q7).
- **`config.json`** (Secret) ne contient que le DataStore :

  ```json
  { "@type": "PostgreSql", "host": "stalwart-rw.mail.svc", "port": 5432,
    "database": "stalwart", "authUsername": "stalwart",
    "authSecret": { "@type": "EnvironmentVariable", "variableName": "STALWART_DB_PASSWORD" } }
  ```

- **BlobStore :** singleton S3 posé par le Job de bootstrap.

  ```json
  { "@type": "S3", "region": "Custom", "customRegion": "weebo",
    "customEndpoint": "https://s3-main.weebo.poc", "bucket": "stalwart", ... }
  ```

  Le bucket, son user et sa policy sont dans `2.terra/vault/terra-map/s3.tf`,
  à côté de ceux de forgejo.
- **Listeners :** submission 587 (STARTTLS), SMTP 25 (inter-apps,
  authentification obligatoire), IMAPS 993, HTTPS 443 (WebUI et JMAP),
  management 8080 en interne. Tous en ClusterIP. Seul le HTTPS est exposé, par
  une IngressRoute Traefik `mail.weebo.poc`.
- **TLS :** Certificate cert-manager (CA interne) monté en volume. L'import
  dans un objet `x:Certificate` (ou une référence au fichier) reste à
  vérifier au spike (Q5).
- **Probes :** `/healthz/live` et `/healthz/ready` sur le listener de
  management.
- **CiliumNetworkPolicy :**
  - egress limité à kube-dns, `stalwart-rw` (5432), RustFS (443) et
    l'issuer Authentik (443, discovery et JWKS) ;
  - ingress 587/25/993 limité aux namespaces listés dans les values, 443
    depuis Traefik ;
  - 8080 depuis `weebo-stalwart` seulement.
- **Authentik :** une entrée `stalwart` dans `auth/sub/values.yaml`
  (`applications`), provider oauth2, client public pour la WebUI, audience
  `stalwart`, scopes `openid email profile groups`, `secretTargets` vers
  `mv/mail/auth`. La directory `Oidc` de Stalwart :

  ```json
  { "@type": "Oidc", "issuerUrl": "https://auth.weebo.poc/application/o/stalwart/",
    "requireAudience": "stalwart", "claimUsername": "preferred_username",
    "usernameDomain": "weebo.poc", "claimName": "name", "claimGroups": "groups" }
  ```

- **Bootstrap** (Job PostSync `stalwart-bootstrap`, idempotent) :
  1. attendre `/healthz/ready` ;
  2. avec l'admin de recovery (`STALWART_RECOVERY_ADMIN`, lu dans
     `mv/mail/admin`), lancer `stalwart-cli apply` sur un plan d'`upsert`
     (BlobStore, Directory `Oidc`, `Authentication.directoryId`, compte
     `weebo-stalwart`) ;
  3. si `mv/mail/operator` est vide, créer l'ApiKey `weebo-stalwart`
     (permissions `Replace`, voir *Sécurité*) et écrire son secret dans
     `mv/mail/operator`.

  C'est le schéma du Job token de forgejo
  (`2.argo/helm/forgejo/templates/operator/token.yaml`). L'admin de recovery
  reste en place comme break-glass, son mot de passe dans Vault, comme
  `mv/forgejo/admin`.
- **Vault :**
  - `2.terra/vault/terra-map/mail.tf` crée `mv/mail/{pg,admin,s3}`, le rôle
    `mail-read` (ExternalSecrets) et le rôle `stalwart-operator` (SA
    `weebo-stalwart` du namespace `weebo-stalwart`) ;
  - la `StalwartInstance` pose `secretStore.vault.pathPrefix: ""`. La règle
    du kit (`<pathPrefix>/<namespace>/`) donne alors `mv/<namespace>/<name>`,
    soit `mv/forgejo/smtp` pour un CR du namespace `forgejo`. Aucun
    `pathGrants` n'est nécessaire, puisque chaque CR écrit dans son propre
    sous-arbre. La policy Vault du rôle se limite à `mv/+/smtp` et
    `mv/mail/*`.

### Brancher les apps

| App | Chart | Config, alimentée par `mv/<app>/smtp` |
| --- | --- | --- |
| Authentik | `auth/main` | `AUTHENTIK_EMAIL__HOST`, `__PORT`, `__USERNAME`, `__PASSWORD`, `__USE_TLS=true`, `__FROM` |
| Forgejo | `forgejo` | `[mailer] ENABLED=true`, `PROTOCOL=smtp+starttls`, `SMTP_ADDR`, `SMTP_PORT`, `USER`, `PASSWD`, `FROM` |
| Argo CD | `argocd-notifications-cm` | `service.email: {host, port, from, username: $email-username, password: $email-password}` |
| Monitoring | ClickStack | alertes email si HyperDX les propose ; sinon hors périmètre |
| BatleHub | `batlehub` | quand BatleHub exposera une config SMTP |
| Che | — | rien côté serveur ; un dev peut soumettre sur 587 avec son App Password |

## Sécurité

- **Privilèges dans Stalwart :** l'ApiKey de l'opérateur est en
  `permissions: Replace` avec seulement :
  - `sysDomain{Get,Create,Update,Query}` (pas `Destroy`, on suit le
    `Orphan` par défaut, voir Q6) ;
  - `sysAccount*`, `sysMailingList*`, `sysAppPassword*` ;
  - les permissions de lecture de version et de schéma.

  Pas d'`impersonate`, aucun `jmapEmail*`, aucun singleton de settings.
  L'opérateur ne peut lire aucun mail. Le bootstrap seul touche aux
  singletons, avec l'admin de recovery.
- **Privilèges Kubernetes :**
  - CRUD sur ses CRDs, et aucun droit sur les CRD d'un autre opérateur ;
  - Secrets de son namespace (jeton de l'instance) et des cibles
    `kubernetes` ;
  - Events et Lease.
- **Vault :** le rôle `stalwart-operator`, en écriture sur `mv/+/smtp` et
  `mv/mail/*`. La règle de chemin du kit interdit à un CR d'écrire hors de
  son namespace, et le check-and-set avec owner empêche d'écraser une valeur
  qu'un autre objet possède.
- **Frontière de confiance :**
  - **Les CR des namespaces d'apps.** Ils sont bornés par la
    `StalwartNamespacePolicy` (kind, domaine), et les alias restent dans le
    domaine du compte. Un namespace autorisé à créer un
    `StalwartServiceAccount` choisit son local-part : sans borne, il
    pourrait prendre `admin@weebo.poc` ou le nom d'un futur utilisateur. On
    le borne avec la dimension `names` du kit :
    - une règle `Deny` sur les noms d'infra (`postmaster`, `abuse`, `admin`…) ;
    - idéalement, une règle `Allow` par namespace qui liste ses noms
      (`forgejo: [forgejo, noreply]`), comme `allowedUsers` chez forgejo.

    La revendication unique fait le reste : un nom déjà possédé par un CR
    ne peut pas être repris.
  - **La brique de liaison.** Elle crée et verrouille des `StalwartAccount`,
    bornée par la même `StalwartNamespacePolicy` que les autres clients
    (namespace `mail`, dimension `names`). Compromise, elle peut verrouiller
    des boîtes ou en créer, jamais lire de mail ni toucher aux comptes
    d'envoi des apps, qui vivent dans d'autres namespaces.
- **Contournements :**
  - CR créés avant le webhook : le reconciler revérifie la policy.
  - Comptes créés à la main dans la WebUI : ils sont invisibles pour
    l'opérateur. Un CR du même nom échoue en `StalwartObjectAlreadyExists`
    jusqu'à un import explicite.
  - Comptes créés par la JIT OIDC avant leur `StalwartAccount` : le CR
    échoue en `StalwartObjectAlreadyExists`, qu'il vienne d'un humain ou de
    la brique de liaison. Seul l'importer les relie, après la garde de
    revendication unique.
  - Usurpation de `From` : Stalwart limite déjà le `MAIL FROM` aux adresses
    du compte authentifié (à confirmer au spike, Q8).
- **Rayon d'impact :** un opérateur compromis peut créer ou verrouiller des
  comptes, réinitialiser le mot de passe des comptes d'envoi et lire les
  secrets qu'il publie. Il ne peut ni lire de mail, ni changer la config du
  serveur, ni rien envoyer hors du cluster (D12). Un Stalwart compromis
  reste enfermé dans le namespace `mail` par l'egress.
- **Secrets :** les mots de passe et les secrets d'App Password ne sont
  jamais logués, ni mis dans le status ou les Events. Le status ne porte que
  `secretVersion` et `rotatedAt`. Le client JMAP masque le header
  `Authorization` dans ses traces OTLP.

## Exploitation

- **Mode d'échec :**
  - *Stalwart :* opérateur arrêté, le mail continue de fonctionner. On ne
    perd que la création et le verrouillage.
  - *Webhook :* `Fail`, sur les seuls kinds `stalwart.weebo.io`. Ne rien
    pouvoir créer pendant une panne de l'opérateur est préférable à un
    compte créé hors policy, et ces CR ne sont sur le chemin d'aucun Pod.
  - *Verrouillage :* il dépend de l'opérateur et de la brique de liaison.
    Si l'un des deux est arrêté, un user retiré d'Authentik ne peut déjà
    plus se connecter par OIDC (Authentik le refuse), mais ses App
    Passwords restent valides jusqu'à leur retour. C'est accepté, et visible par l'alerte « opérateur sans
    leader » des métriques du kit (le status, lui, n'avance plus).
- **Rollout :**
  1. Phase 0 : Stalwart, bootstrap et domaine par un plan `apply`, sans
     opérateur. Envoi de test depuis un pod.
  2. Opérateur avec `StalwartInstance`, puis `weebo-stalwart-importer` pour
     relier le domaine et les comptes créés par le plan à leurs CR
     (`import-pending`). C'est le chemin de migration du kit, jamais une
     adoption par nom.
  3. `StalwartServiceAccount` forgejo, test de reset de mot de passe de bout
     en bout, puis Authentik, puis Argo CD.
  4. `StalwartAccount` d'un seul user déclaré à la main, verrouillage et
     déverrouillage vérifiés. La généralisation à tous les users passe par
     la brique de liaison, dans sa propre RFC.
- **Rollback :**
  - Supprimer un CR avec `force-orphan` laisse l'objet Stalwart intact.
  - Couper l'Application `weebo-stalwart` laisse Stalwart servir avec ce
    qu'il a.
  - Revenir en phase 0, c'est réappliquer le plan.
  - Les apps reviennent à « pas de mail » en retirant leur config SMTP.
- **Observabilité :**
  - `Ready` par CR, Events et métriques du kit vers otel-cluster ;
  - métriques Stalwart scrapées ;
  - une Probe blackbox TCP+STARTTLS sur 587 et TLS sur 993, ajoutée au
    dashboard « Probe health » ;
  - alertes : `StalwartInstance` pas `Ready` depuis plus de 10 min, file
    sortante non vide depuis plus de 15 min (rien ne devrait y rester puisque
    tout est local), un `StalwartAccount` pas `Ready` depuis plus de 10 min.
- **Montée de version :**
  - **Stalwart.** Mineures épinglées. Une nouvelle mineure passe d'abord par
    le test de contrat du client contre l'image, puis par la constante de versions supportées de l'opérateur (`UnsupportedStalwartVersion` en dehors).
    L'API de gestion v0.16 est jeune : on s'attend à des ruptures en v0.17.
  - **Opérateur.** Une seule réplique active (lease), et les objets sont
    idempotents. Pendant un rolling update, l'ancien et le nouveau ne
    réconcilient jamais en même temps.

## Alternatives considérées

1. **Pas d'opérateur : un Job `stalwart-cli apply` rendu depuis les values
   Helm.** Les plans d'`upsert` sont idempotents, `reconcile` sait même
   supprimer ce qui manque. C'est suffisant pour les objets statiques
   (domaine, comptes des apps, groupes), et c'est exactement la **phase 0**.
   Ça ne couvre pas :
   - l'écriture des mots de passe vers Vault (il faudrait les générer dans
     Terraform et les injecter dans le plan, soit deux sources de vérité) ;
   - le verrouillage et les App Passwords ;
   - un état par objet.

   L'opérateur ne remplace le plan que là où le plan ne suffit pas.
2. **SCIM depuis Authentik.** C'est la réponse officielle aux points 1 et 2
   de la motivation, et Authentik sait émettre du SCIM. Mais c'est l'édition
   Enterprise de Stalwart, donc une licence, et ça ne fait rien pour les
   comptes d'apps, Vault ou les App Passwords. À reconsidérer si une licence
   arrive.
3. **Provider Terraform dans `2.terra`.** C'est cohérent avec `2.terra/auth`.
   Mais aucun provider maintenu pour l'API JMAP v0.16 n'est connu à ce jour,
   on perd la boucle de réconciliation, et le cycle de vie des users vit dans
   Argo, pas dans Terraform.
4. **Étendre weebo-authentik** pour qu'il pousse lui-même les comptes vers
   Stalwart. Ça mélangerait deux produits dans un opérateur, et ça casse la
   règle du kit : un opérateur par produit.
5. **Un kind `StalwartAccountSource` dans weebo-stalwart**, qui watcherait
   les `AuthentikUser` (brouillon initial de cette RFC). Même défaut, dans
   l'autre sens : l'opérateur Stalwart dépendrait du CRD d'un autre
   opérateur, et chaque paire de produits réinventerait son propre lien.
   Écarté au profit d'une brique de liaison commune (D7).
6. **Un autre MTA.**
   - Mailpit capture les mails des apps sans rien délivrer, ce qui suffit
     pour du dev mais ne donne de boîte à personne.
   - Postfix + Dovecot + LDAP coûtent trois briques à opérer, et
     l'authentification OIDC y est bricolée.
   - Maddy est plus léger, mais sans OIDC ni API de gestion.
7. **Ne rien faire.** Les apps restent sans mail : pas de reset de mot de
   passe autonome, pas de notifications. C'est vivable aujourd'hui (un seul
   utilisateur réel), mais pas avec les équipes que prépare
   weebo-si-hardening.

## Inconvénients et risques

- **Un quatrième opérateur maison à maintenir**, sur une API amont jeune. La
  v0.16 vient de remplacer toute l'API REST, et une v0.17 peut à nouveau
  casser le client. On l'atténue par le test de contrat contre l'image et par
  la plage de versions supportées.
- **Deux écrivains sur `x:Account`** (opérateur et JIT OIDC). D5 et D6 les
  séparent par champ, mais une JIT qui écrirait un champ qu'on croit à nous
  ferait osciller l'objet. Le spike doit lister ce que la JIT touche (Q3).
- **Le verrouillage n'est pas un état natif.** Il repose sur des permissions
  désactivées : si l'opérateur part, l'état `Locked` reste dans Stalwart,
  mais personne ne le surveille.
- **Pas de garantie de délivrance hors du cluster.** C'est voulu, mais une
  app configurée pour écrire à une adresse externe verra ses mails rejetés.
  Ce sera visible dans la file Stalwart, pas dans l'app.
- **Les boîtes des users dépendent d'une brique qui n'existe pas encore.**
  Tant que la brique de liaison n'est pas là, les `StalwartAccount` se
  déclarent à la main, et un départ d'Authentik ne verrouille rien tout
  seul. La v1 de l'opérateur reste utile sans elle (comptes d'envoi des
  apps), et son contrat CR ne bouge pas quand elle arrive.

## Questions ouvertes

Les questions bloquantes sont tranchées par un **spike** (Stalwart v0.16 en
podman, plan de test dans le plan d'implémentation) avant de passer en
`Accepted`.

| # | Question | Bloquant |
| --- | --- | --- |
| Q1 | Une ApiKey créée par l'admin de recovery pour le compte `weebo-stalwart` s'utilise-t-elle en `Authorization: Bearer` sur `/api` (c'est ce que fait `stalwart-cli --api-key`) ? Avec `Replace`, quelles permissions faut-il en plus pour `/api/schema` et la version ? Sinon, le Secret de `tokenSecretRef` porte `user:password` et la gateway envoie du Basic (D10), sans changer le CRD. | oui |
| Q2 | `x:AppPassword/set` (et `x:ApiKey/set`) renvoie-t-il `secret` dans `created` ? Un admin peut-il en créer un pour un autre compte, et par quel champ ? | oui pour `StalwartAppPassword`, non pour la v1 |
| Q3 | La JIT OIDC rattache-t-elle un login au compte pré-créé de même `name` + domaine, ou en crée-t-elle un second ? Quels champs écrit-elle à chaque login ? | oui |
| Q4 | Forme exacte de `Account.permissions` (variantes et champs) pour désactiver `authenticate`, `emailSend` et `emailReceive`. `emailReceive` désactivé rejette-t-il au `RCPT` ? | oui |
| Q5 | Certificat des listeners : un `x:Certificate` doit-il porter le PEM (et donc être recopié à chaque renouvellement cert-manager), ou peut-il pointer un fichier ? | non (contournement : Job de recopie au renouvellement) |
| Q6 | Faut-il `sysDomainDestroy` ? Proposition : non, un domaine se supprime à la main. | non |
| Q7 | Faut-il faire passer le pull de l'image Stalwart par angos ? | non |
| Q8 | Stalwart refuse-t-il par défaut un `MAIL FROM` hors des adresses du compte authentifié ? | non (sinon : règle `MtaStageMail`) |
| Q9 | `dkimManagement: Automatic` sans `dnsManagement` automatique génère-t-il quand même une clé (sans rotation) ? | non |

## Travaux futurs

- **Mode *managed* :** `StalwartInstance.spec.managed` déploie Stalwart avec
  le socle workload du kit v0.17, comme weebo-angos le prévoit, et remplace
  le chart maison de `2.argo/helm/mail`.
- **Domaine public `weebo.[fr/net/…]`** : MX, SPF, DMARC, DKIM publié,
  relais sortant. C'est le seul trou à ouvrir dans l'egress (D12), et il
  fera l'objet d'une RFC à part.
- **Netbird :** IMAP et submission depuis le poste sans passer par Traefik.
- **`StalwartSieveScript`** (filtres par compte) et boîtes partagées avec
  ACL.
- **La brique de liaison entre opérateurs** (RFC à part) : `AuthentikUser`
  → `StalwartAccount`, départ → `state: Locked`, groupes Authentik →
  `StalwartGroup`. Elle consomme le contrat de *Ce que la brique de liaison
  consomme*.
- **SCIM**, si une licence Enterprise arrive. Il ferait, pour Stalwart seul,
  le travail de la brique de liaison.
- **Une `StalwartLocalInstance` utilisée**, si une équipe veut son propre Stalwart : le kind existe dès la v0.1.0 (D2), il ne manque que le déploiement.
- **Ce que le spike pousserait dans le kit**, par exemple un client JMAP générique si un second opérateur JMAP arrive (règle des deux opérateurs).

## Plan d'implémentation

Chaque case est une PR qu'on peut merger seule.

**Spike (avant `Accepted`)**

- [ ] Stalwart v0.16 en podman, avec un Authentik de test ou un IdP mock :
      réponses à Q1–Q4, Q8 et Q9, consignées dans le changelog de cette RFC

**Phase 0 — weebo-si, sans opérateur**

- [ ] `2.terra` : `mv/mail/{pg,admin,s3}`, bucket RustFS `stalwart`, rôles
      `mail-read` et `stalwart-operator`
- [ ] `auth/sub` : application `stalwart` (oauth2, `mv/mail/auth`)
- [ ] `2.argo/helm/mail` : CNPG, Certificate, StatefulSet, Services,
      IngressRoute, CiliumNetworkPolicy
- [ ] Job `stalwart-bootstrap` et plan `apply` (BlobStore, Directory,
      domaine, compte et ApiKey de l'opérateur)
- [ ] Forgejo branché en SMTP sur un compte du plan, reset de mot de passe
      testé de bout en bout
- [ ] Probe blackbox 587/993 et panneau dans « Probe health »

**Phase 1 — weebo-stalwart v0.1.0**

- [ ] Dépôt rendu par `task template:render` / `cargo generate --tag v0.17.0 templates/operator`
      (`product = Stalwart`), sans retrait : `StalwartInstance`,
      `StalwartLocalInstance`, `Status` et `ReasonCode` du template ;
      `cog.toml` du kit, `checks.yml` / `publish.yml` par tag, chart sur
      `weebo-operator-lib`
- [ ] `task test:all`, `task audit` et le budget `weebo-kit-perf` verts
      dès la première PR
- [ ] Client JMAP et test de contrat contre l'image v0.16
- [ ] `StalwartInstance` (`ping`, version), `StalwartNamespacePolicy`,
      webhook
- [ ] `StalwartDomain` (cluster-scoped, dimension `domains`)
- [ ] `weebo-stalwart-importer` (`import-pending`, garde `RemoteObjectClaimed`) pour reprendre le domaine et les comptes de la phase 0
- [ ] `StalwartServiceAccount` : `emit` (`write_all`, `any_missing`, `rotation_requested`), dimension `names`
- [ ] weebo-si : opérateur en wave 3, comptes de forgejo, Authentik et
      Argo CD en CR, retrait du plan pour ces objets

**Phase 2 — weebo-stalwart v0.2.0**

- [ ] `StalwartAccount` (`state`, verrouillage)
- [ ] `StalwartGroup`, `StalwartMailingList`
- [ ] `StalwartAppPassword` (selon Q2)
- [ ] weebo-si : un `StalwartAccount` déclaré à la main dans `2.argo/helm/mail`,
      verrouillage vérifié ; le reste des users attend la brique de liaison

**Clôture**

- [ ] Doc : Big Picture Mail, page Macro, doc de l'opérateur
      (`@weebo/operator-docs`), left-todo mis à jour
- [ ] RFC passée en `Implemented`

## Références

- [Stalwart v0.16 : l'API de gestion passe en JMAP](https://stalw.art/blog/stalwart-0-16)
- [Directory OIDC et ses limites](https://stalw.art/docs/auth/backend/oidc/)
- [Index du schéma](https://www.stalw.art/docs/ref/) : [Account](https://www.stalw.art/docs/ref/object/account/), [Domain](https://www.stalw.art/docs/ref/object/domain/), [MailingList](https://www.stalw.art/docs/ref/object/mailing-list/), [ApiKey](https://www.stalw.art/docs/ref/object/api-key/), [AppPassword](https://www.stalw.art/docs/ref/object/app-password/), [BlobStore](https://www.stalw.art/docs/ref/object/blob-store/), [Role](https://www.stalw.art/docs/ref/object/role/), [Permissions](https://www.stalw.art/docs/ref/permissions/)
- [CLI](https://www.stalw.art/docs/management/cli/) et [`apply`](https://www.stalw.art/docs/management/cli/apply/), [déploiements déclaratifs](https://www.stalw.art/docs/configuration/declarative-deployments/)
- [Kubernetes (chart d'exemple, StatefulSet)](https://stalw.art/docs/cluster/orchestration/kubernetes)
- weebo-operator-kit v0.17.0 : `docs/plan.md` (« Ce qui va dans le kit », garde-fous, NamespacePolicy, v0.17.0), `docs/rfc-vault-path-grants.md`, `templates/operator`, `crates/weebo-kit-api` (`InstanceRef`, `ObjectRef`, `SecretTarget`, annotations), `crates/weebo-kit-domain/src/allow_list.rs`, `crates/weebo-kit-application/src/emit.rs`
- Modèles internes : `2.argo/helm/forgejo` (opérateur, Job token, NamespacePolicy, `secretTargets`), `2.argo/helm/batlehub` (mode external), `2.argo/helm/auth/sub` (applications, users)
- weebo-si-hardening : gabarit RFC (`docs/rfc/0000-template.md`)

## Changelog

| Date | Changement |
| --- | --- |
| 2026-10-18 | Brouillon initial |
| 2026-10-18 | Alignement strict sur weebo-operator-kit v0.17.0 : `LocalInstance` gardée, `StalwartDomain` cluster-scoped (`ObjectRef` sans namespace), dimensions d'allow-list `domains`/`names` au lieu de `reservedNames`, plus d'adoption par nom (importer + `import-pending`), `deletionPolicy` limitée à `Delete`/`Orphan`, `rotate-secret` en nonce, `Status` et codes du template, plus de `basicAuthSecretRef` ni de `versionRange`, `pathPrefix: ""` sans `pathGrants` |
| 2026-10-18 | Lien Authentik → Stalwart sorti de l'opérateur : `StalwartAccountSource`, reflector `AuthentikUser`, RBAC sur `authentik.weebo.io` et codes `SourceOutsideScope`/`ChildrenNotReady` retirés. Une autre brique, qui lie les opérateurs entre eux, consomme les `StalwartAccount` (D7, alternative 5) |
