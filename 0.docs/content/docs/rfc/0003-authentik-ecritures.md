---
title: "RFC 0003 — weebo-authentik n'écrit que ce qui diffère"
description: "L'opérateur réécrit chaque objet Authentik toutes les 5 minutes sans rien changer ; il doit comparer avant d'écrire, comme weebo-forgejo"
rfc: 0003
status: Draft
authors: [batleforc]
created: 2026-10-18
updated: 2026-10-18
decided:
brick: github.com/batleforc/weebo-authentik, github.com/batleforc/weebo-operator-kit
supersedes: []
superseded-by: []
---

# RFC 0003 — weebo-authentik n'écrit que ce qui diffère

- **Dépôts :** `weebo-authentik` (le correctif), `weebo-operator-kit` (helpers
  de comparaison et template), weebo-si (rien à changer, sinon retirer les
  palliatifs)
- **Base :** weebo-authentik v0.18.1 (kit v0.16.0), Authentik 2026.8.0
- **Constaté le :** 2026-10-18, pendant la migration CNPG d'Authentik

## Résumé

À chaque réconciliation, soit toutes les 5 minutes (`STEADY_REQUEUE_SECS` du
kit), weebo-authentik envoie un PATCH pour chaque objet qu'il gère, même
quand rien n'a changé. Authentik enregistre chacun de ces PATCH comme un
événement `model_updated`. Chaque événement déclenche des tâches, et chaque
sauvegarde de provider reconstruit les permissions de l'outpost et lui pousse
une mise à jour. Sur un cluster où aucun CR n'avait changé en 24 heures, ça
représente environ 13 300 événements par jour (99,96 % des événements
d'Authentik), 65 000 tâches par jour, et 3 Go de base en un mois.

La correction : pour chaque kind, lire l'objet distant, le comparer à l'état
voulu, et n'écrire que s'il diffère. C'est déjà ce que fait weebo-forgejo
(`differs`, test `creates_then_stays_quiet_until_drift`). Les helpers de
comparaison passent dans le kit, puisque deux opérateurs en ont besoin, et
le template cesse de présenter « on écrit à chaque fois » comme le modèle.

## Motivation

### Ce qu'on a mesuré (2026-10-18, sur 24 h)

Aucun des 28 CR de weebo-authentik n'avait vu sa spec ou ses métadonnées
modifiées. Les événements `model_*` produits dans le même temps par
`akadmin` avec l'agent `OpenAPI-Generator/2026.5.4/rust` (le client de
l'opérateur) :

| Objet Authentik | `model_updated` / jour | Objets | Une écriture par objet toutes les |
| --- | --- | --- | --- |
| `policybinding` | 2 504 | 9 | 5,2 min |
| `application` | 2 491 | 9 | 5,2 min |
| `oauth2provider` | 1 938 | 7 | 5,2 min |
| `proxyprovider` | 1 106 | 2 | 2,6 min |
| `group` | 1 080 | 4 | 5,3 min |
| `scopemapping` | 848 | 3 | 5,1 min |
| `brand` | 558 | 1 | 2,6 min |
| `user` | 283 | 1 | 5,1 min |
| `flow` | 277 | 1 | 5,2 min |
| `outpost` | 63 | 1 | 23 min |

S'y ajoutent environ 1 100 `rolemodelpermission` supprimées puis recréées
par jour, autant que de sauvegardes de `proxyprovider`. Au total, sur la
fenêtre mesurée (17 octobre 11:00 – 18 octobre 11:00), **13 323 des 13 328
événements d'Authentik (99,96 %)** sont des écritures de l'opérateur.

Le rythme d'environ 5,2 min correspond au requeue de 300 s du kit. Il reste
à expliquer pourquoi les proxy providers et la brand sont réécrits deux fois
par cycle. La piste la plus probable : un second chemin les écrit, par
exemple la réconciliation de l'Application en plus de la leur.

Ce que ça coûte :

- **Base de données :** 94 % des tâches sont des `event_trigger_handler` ou
  `event_trigger_dispatch` lancées par ces événements. Sur 30 jours, cela
  donne 2 M de tâches et 6,3 M de lignes de log (2,4 Go), plus 537 000
  événements (538 Mo), sur une base de 3 Go. Avant l'opérateur, en juin,
  juillet et août, il y avait une centaine d'événements par mois.
- **Outpost :** « Provider changed, rebuilding permissions and sending
  update » toutes les 2 minutes dans les logs. Le proxy embarqué recharge sa
  config sans raison, et Authentik supprime puis recrée les permissions de
  ses rôles.
- **Audit :** les événements utiles (logins, autorisations, changements de
  mot de passe, une dizaine par jour) sont noyés dans le bruit.

### Palliatifs déjà posés dans weebo-si (2026-10-18)

- `AUTHENTIK_WORKER__TASK_EXPIRATION=days=7` au lieu de 30.
- `event_retention` du tenant à `days=90` au lieu de 365, posé en base.

Ils bornent la taille, sans réduire le volume. Une fois cette RFC
implémentée, les deux peuvent revenir à leurs valeurs par défaut.

### Une fois en place

- Une réconciliation sans changement fait des lectures, et **aucune
  écriture**.
- Le nombre d'événements `model_*` signés par l'opérateur suit le nombre de
  changements réels. Au repos, il tombe à zéro.
- La dérive est toujours corrigée : un objet modifié à la main dans
  l'interface d'Authentik est remis en état au passage suivant, avec un
  Event Kubernetes qui le signale.

## Design

### Le principe, par kind

Pour chaque objet :

1. Construire l'état voulu depuis la spec. C'est déjà fait : c'est le corps
   des requêtes actuelles.
2. Lire l'objet distant. Il y a déjà un GET pour l'Application, il en faut
   un par kind.
3. Comparer **seulement les champs que l'opérateur possède**. Un champ que
   la spec ne renseigne pas (`None`) n'est « pas d'avis », comme
   `differs()` chez forgejo, et ne force jamais d'écriture.
4. S'il y a une différence, envoyer un PATCH **de ces seuls champs**, et
   émettre un Event `Normal` `DriftCorrected` qui liste les champs
   concernés. Sinon, aucun appel en écriture.

Les références sont comparées une fois résolues. Les flows sont résolus par
slug, les property mappings et les certificats par nom, et l'opérateur les
résout déjà avant chaque écriture. On compare donc des pk avec des pk.

### Les comparaisons délicates

| Kind | Champs comparés | Attention |
| --- | --- | --- |
| Application | `name`, `slug`, `provider`, `meta_icon` | `meta_icon` `None` = pas d'avis |
| OAuth2Provider | `name`, flows (pk), `property_mappings` (ensemble de pk), `client_type`, `grant_types` (ensemble), `client_id`, `access_token_validity`, `signing_key` (pk), `redirect_uris` (ensemble de `(matching_mode, url)`) | ordre non significatif pour les listes ; `access_token_validity` comparée telle qu'Authentik la renvoie, sinon la normaliser des deux côtés ; `client_secret` jamais lu ni écrit ici |
| ProxyProvider | comme OAuth2 pour les flows et mappings, plus `mode`, `external_host`, `internal_host`… | c'est la sauvegarde qui reconstruit les `rolemodelpermission` : une écriture évitée ici en évite trois |
| PolicyBinding | `group` (pk), `target`, `order`, `negate`, `enabled` | la résolution du groupe par nom et de l'Application cible reste une lecture |
| Group | `name`, `is_superuser`, `parent`, `attributes` | `attributes` comparés comme sous-ensemble : seules les clés de la spec, en égalité profonde |
| User | `username`, `name`, `email`, `is_active`, `groups` (ensemble) | |
| Brand | `domain`, `default`, flows, `attributes`… | brand par défaut : le basculement existant (#16) reste tel quel |
| Flow, ScopeMapping, Outpost | champs de la spec ; providers de l'outpost en ensemble | `expression` d'un ScopeMapping comparée aux espaces de début et de fin près (`same_trimmed`) : comparée octet pour octet en v0.18.2, elle dérive à chaque passage (voir *La normalisation du serveur*) |

Le principe : **une liste dont l'ordre n'a pas de sens pour Authentik se
compare comme un ensemble**. Une liste ordonnée se compare telle quelle. Si
le doute subsiste pour un champ, il le dit dans son test.

### Dans le kit (règle des deux opérateurs)

Deux opérateurs comparent déjà avant d'écrire, chacun à sa façon :

- **weebo-forgejo** (`crates/application/src/use_cases/mod.rs`) : des
  prédicats `differs(&Option<String>, &str)` et
  `differs_flag(Option<bool>, bool)`, combinés en `organization_differs()`
  ou `hook_differs()`. Une dérive envoie le PATCH complet, et le nom du
  champ dérivé n'est conservé nulle part.
- **weebo-authentik** v0.18.2 (`crates/domain/src/drift.rs`, ~80 lignes
  hors tests) : `Drift` nettoie le PATCH lui-même. Chaque champ égal au
  distant passe à `None`, et sort donc de la requête. Chaque champ qui
  diffère est noté. Cette version est en production et a passé l'e2e
  contre un vrai Authentik.

**Le kit reprend l'API de weebo-authentik**, dans `weebo-kit-domain::drift`.
Elle couvre ce que fait forgejo et ajoute ce qui lui manque : le PATCH réduit
aux seuls champs dérivés (D3) et la liste des champs pour l'Event (D4). Le
module est pur : pas de `tracing`, pas de `kube`, aucune dépendance hors
`std`.

```rust
/// Champs dont la valeur voulue diffère du distant, dans l'ordre des appels.
pub struct Drift(Vec<&'static str>);

impl Drift {
    pub fn is_empty(&self) -> bool;
    pub fn fields(&self) -> &[&'static str];

    /// `desired` : le champ du PATCH (`None` = pas envoyé, pas d'avis).
    /// Égal : `desired` passe à `None`, le champ sort du PATCH.
    /// Différent : il reste, et `field` est noté.
    pub fn keep<T: PartialEq>(&mut self, field: &'static str,
                              desired: &mut Option<T>, remote: &T);
    /// Distant que le serveur peut laisser vide : `None` distant ≠ voulu.
    pub fn keep_opt<T: PartialEq>(&mut self, field: &'static str,
                                  desired: &mut Option<T>, remote: &Option<T>);
    /// Égalité fournie par l'appelant : ensemble, sous-ensemble, type
    /// distant différent du type de requête, normalisation du serveur.
    pub fn keep_with<T, R>(&mut self, field: &'static str,
                           desired: &mut Option<T>, remote: &R,
                           same: impl FnOnce(&T, &R) -> bool);
    /// Pour l'appelant qui n'a pas de PATCH en `Option` (forgejo) : noter
    /// un champ à partir d'un prédicat déjà calculé.
    pub fn note(&mut self, field: &'static str, differs: bool);
}

/// Mêmes éléments, ordre ignoré, doublons comptés (`PartialEq` seul).
pub fn same_set<T: PartialEq>(a: &[T], b: &[T]) -> bool;
/// Chaque clé voulue a la valeur voulue ; les autres clés distantes
/// (défauts ajoutés par le serveur) sont ignorées.
pub fn same_subset<K, V, S1, S2>(desired: &HashMap<K, V, S1>,
                                 remote: &HashMap<K, V, S2>) -> bool;
/// Égales aux espaces de début et de fin près (voir plus bas).
pub fn same_trimmed(desired: &str, remote: &str) -> bool;
```

Par rapport à `domain::drift` de weebo-authentik, deux ajouts : `note`, pour
que forgejo y bascule sans réécrire ses PATCH, et `same_trimmed`, après la
mise en production (voir ci-dessous). Les 8 tests de weebo-authentik
partent avec le module.

**Ce qui reste dans chaque opérateur :** l'appel aux helpers, champ par
champ, dans l'adaptateur sortant (après la résolution des références) ou
dans le use-case, selon l'endroit où l'opérateur construit son PATCH. Le
journal `drift corrected` (aujourd'hui `must_write()` dans l'adaptateur de
weebo-authentik) reste lui aussi dans l'opérateur, en attendant l'Event.

#### La normalisation du serveur

Comparer le PATCH au distant suppose que le serveur renvoie ce qu'on lui a
écrit. Ce n'est pas toujours le cas, et chaque écart produit une dérive
permanente : une écriture à chaque passage, c'est-à-dire le bug
d'origine, sur un seul champ.

Cas observé à la mise en production de v0.18.2 (2026-10-18) : les 3
`AuthentikScopeMapping` sont corrigés sur `expression` à chaque cycle
(`drift corrected fields=["expression"]` à 17:21 puis 17:26, sans
changement de CR). Leur spec est un bloc YAML `|`, qui finit donc par
`\n`. La cause la plus probable est qu'Authentik retire les espaces de
début et de fin, comme le fait par défaut un `CharField` de Django REST
Framework (`trim_whitespace=True`). Ce n'est pas encore vérifié côté base.

La règle pour le kit et pour les opérateurs :

1. **On compare à la forme que le serveur stocke**, pas à celle qu'on
   envoie. Quand le serveur normalise (espaces retirés, casse, durées
   réécrites, défauts ajoutés dans une map), la comparaison applique la même
   normalisation via `keep_with` (`same_trimmed`, `same_subset`…). On
   n'envoie pas une valeur normalisée à la place de celle de la spec.
2. **Chaque normalisation a son test de contrat** : le distant renvoyé
   normalisé, et aucun PATCH attendu.
3. **Le test « reste silencieux » du template s'exécute contre le vrai
   serveur** quand l'opérateur a un e2e. Un faux distant qui renvoie ce
   qu'on lui écrit ne voit pas ce cas : les tests wiremock de
   weebo-authentik étaient verts.
4. **Une dérive qui revient au cycle suivant sur le même champ est un bug
   de comparaison**, pas une dérive. Le compteur `remote_writes_total`
   (D6) et l'alerte proposée dans *Exploitation* servent à la repérer.

Le template `templates/operator` change de modèle.
`reconcile_object.rs` décrit aujourd'hui « created or updated on every
reconcile (the gateway's `ensure` is idempotent) ». Il devient « lire,
comparer, écrire seulement en cas de dérive », et son test reprend
`creates_then_stays_quiet_until_drift` : une seconde réconciliation sur un
faux distant inchangé ne fait **aucun** appel en écriture. Les opérateurs
déjà générés ne sont pas touchés, mais un nouvel opérateur, Stalwart
compris (RFC 0001), part du bon modèle.

`ReconcileMetrics` gagne un compteur
`<prefix>_remote_writes_total{kind, cause}`, avec `cause` valant `created`,
`drift` ou `deleted`. Une écriture au repos devient ainsi visible dans les
métriques, au lieu de se découvrir dans la taille d'une base.

### Le requeue

Les 300 s du kit restent. Le correctif ramène une réconciliation au repos à
quelques GET par objet, ce qui est négligeable. Rendre le requeue
configurable ne réglerait pas le problème : moins d'écritures inutiles,
c'est toujours des écritures inutiles.

### Décisions

| # | Décision | Pourquoi |
| --- | --- | --- |
| D1 | Comparer avant d'écrire, pour tous les kinds | C'est la cause. Ralentir le requeue ou purger plus vite ne fait que réduire le symptôme. |
| D2 | `None` dans la spec = pas d'avis | Comme forgejo. Sinon un champ jamais renseigné forcerait un PATCH à chaque passage, ou écraserait un réglage fait à la main. |
| D3 | PATCH des seuls champs qui diffèrent | Un PATCH complet sur un seul champ dérivé réécrit le reste, et peut déclencher les mêmes effets de bord, comme la reconstruction des permissions. |
| D4 | Un Event `DriftCorrected` à chaque correction | Une dérive corrigée sans trace cache une modification manuelle, ou une incompatibilité avec une version d'Authentik. |
| D5 | Helpers et template dans le kit | Deux opérateurs en ont besoin (forgejo l'a déjà, authentik en aurait besoin) : c'est la règle d'entrée dans le kit. |
| D6 | Un compteur `remote_writes_total` | Le bug a tourné six semaines sans se voir. Il se lit maintenant dans un panneau. |

## Sécurité

- **Pas de nouveau droit :** l'opérateur fait déjà des GET sur ces objets
  (Application, résolution des flows, groupes, mappings, certificats).
- **Moins de surface :** moins d'écritures, et l'audit Authentik redevient
  lisible.
- **La dérive reste corrigée.** Un champ possédé modifié à la main est
  réécrit au passage suivant, comme aujourd'hui, mais avec un Event. Un
  champ que la spec ne renseigne pas n'est plus réécrit (D2). Ce n'est pas
  une régression : il n'était déjà pas dans le corps des requêtes.

## Exploitation

- **Validation dans weebo-si :**
  - après déploiement, la requête du tableau de *Motivation* sur une heure
    doit renvoyer 0 événement `model_updated` signé par l'opérateur, hors
    changement de CR ;
  - les logs de l'outpost ne doivent plus montrer « Provider changed… »
    toutes les 2 minutes ;
  - `remote_writes_total{cause="drift"}` doit être à 0 au repos ;
  - en attendant le compteur, aucun log `drift corrected` ne doit revenir
    sur le même objet et le même champ d'un cycle à l'autre.
- **Alerte proposée :** `increase(<prefix>_remote_writes_total{cause="drift"}[30m]) > 3`
  pour un même `kind`. Une vraie dérive se corrige en un passage, une
  comparaison fausse écrit à chaque cycle (six fois en 30 minutes).
- **Test de dérive :** modifier à la main un champ possédé (le nom d'une
  Application dans l'interface). Il doit revenir sous 5 minutes, avec un
  Event `DriftCorrected` qui le nomme.
- **Rollback :** revenir à la version précédente de l'opérateur, qui
  réécrit tout à chaque fois. C'est sans risque pour les données, on
  retrouve seulement le bruit.
- **Après stabilisation :** retirer les palliatifs de weebo-si
  (`AUTHENTIK_WORKER__TASK_EXPIRATION`), ou les garder comme valeurs
  raisonnables. `event_retention` à 90 jours peut rester un choix d'audit.

## Alternatives considérées

1. **Ralentir le requeue** (30 min au lieu de 5). Ça divise le bruit par
   six sans le supprimer, et la dérive est corrigée six fois plus tard.
2. **Ne réconcilier que sur changement de CR** (pas de requeue au repos).
   Une modification faite dans l'interface d'Authentik ne serait plus jamais
   corrigée, ce qui casse le contrat GitOps de l'opérateur.
3. **Comparer un hash de l'état voulu** gardé dans le status. Ça évite le
   GET, mais ne voit pas une dérive côté Authentik : c'est l'alternative 2
   avec un détour.
4. **Filtrer les événements côté Authentik** (désactiver l'enregistrement
   des `model_updated`). Authentik ne le permet pas finement, on perdrait
   l'audit des vraies modifications, et l'outpost continuerait de recharger.
5. **Rester avec les palliatifs.** Ils bornent la base, mais l'outpost
   recharge toujours toutes les 2 minutes et l'audit reste noyé.

## Inconvénients et risques

- **Des comparaisons à écrire et à maintenir pour chaque kind,** en suivant
  les montées de version d'Authentik : un champ renommé ou renormalisé
  produirait une « dérive » permanente. Le compteur `drift` et l'Event la
  rendent visible tout de suite, au lieu de la laisser tourner en silence.
- **Une normalisation ratée** (un ensemble comparé comme une liste, un
  texte dont le serveur retire les espaces…) produit une dérive à chaque
  passage. On retrouve le comportement d'avant, sur un champ, mais visible.
  Le test « reste silencieux » l'attrape seulement s'il tourne contre le
  vrai serveur : celui de v0.18.2, sur wiremock, est passé à côté de
  `expression`.

## Questions ouvertes

| # | Question | Bloquant |
| --- | --- | --- |
| Q1 | Authentik renvoie-t-il `access_token_validity` (et les autres durées) exactement sous la forme écrite (`hours=1`), ou normalisée ? | non (sinon : normaliser des deux côtés) |
| Q2 | L'ordre des `redirect_uris` et des `property_mappings` a-t-il un sens pour Authentik ? Proposé : non, ce sont des ensembles. | non |
| Q3 | ~~Le basculement de brand par défaut (#16) a-t-il besoin d'écrire à chaque passage ?~~ **Tranchée :** non. `toggle_default` réécrivait `default: true` sur une brand déjà par défaut ; corrigé, il n'écrit plus que si la brand par défaut est une autre. | ~~non~~ |
| Q4 | Faut-il un Event `DriftCorrected` par champ, ou un seul par objet avec la liste ? Proposé : un par objet. | non |
| Q5 | Pourquoi les proxy providers et la brand sont-ils écrits deux fois par cycle ? **Brand : tranchée**, c'est `update_brand` puis `set_brand_default` (Q3). **Proxy provider :** l'opérateur ne l'écrit qu'une fois par cycle (un seul `upsert_proxy_provider`) ; la seconde écriture comptée viendrait d'Authentik lui-même, qui sauvegarderait deux fois le provider. Non vérifié, et sans objet une fois le PATCH évité. | non |

## Plan d'implémentation

**weebo-operator-kit**

- [ ] `weebo-kit-domain::drift` : l'API de *Dans le kit*, reprise de
      `weebo-authentik/crates/domain/src/drift.rs` avec ses 8 tests, plus
      `Drift::note` et `same_trimmed` (et leurs tests)
- [ ] `ReconcileMetrics` : `remote_writes_total{kind, cause}`
- [ ] template `reconcile_object` : lire, comparer avec `Drift`, PATCH des
      seuls champs dérivés ; test « reste silencieux » ; doc du template,
      avec la règle de *La normalisation du serveur*
- [ ] release du kit

**Ensuite, dans les opérateurs**

- [ ] weebo-authentik : remplacer `domain::drift` par celui du kit ;
      comparer `expression` (ScopeMapping) avec `same_trimmed`, test de
      contrat avec une expression renvoyée sans `\n` final
- [ ] weebo-forgejo : `differs` / `differs_flag` remplacés par
      `Drift::note` (ou `keep`), pour avoir les champs dans l'Event

**weebo-authentik** (PR #18, release v0.18.2, 2026-10-18)

- [x] lire, comparer et PATCHer les seuls champs dérivés, pour les 10
      kinds. Choix d'implémentation : la comparaison se fait dans
      l'adaptateur, après la résolution des références qu'il fait déjà
      (flows, mappings, certificats, groupes), avec les helpers purs de
      `domain::drift` (`Drift`, `same_set`, `same_subset`). Les ports et
      les use-cases ne changent pas, sauf la brand.
- [x] brand : plus de réécriture de `default: true` (Q3)
- [x] tests : `domain::drift` (8), contrat wiremock (groupe inchangé et
      dérivé, OAuth2 et proxy inchangés), use-case brand (2). Mocks des
      suites envtest ajustés, avec une assertion « binding inchangé
      jamais PATCHé ». Verts en CI : `test:all` (envtest compris), e2e
      (kind + vrai Authentik, les deux images), `task perf` (dans le
      budget, 6 appels API par objet en rafale).
- [ ] `expression` des ScopeMappings : dérive à chaque cycle depuis
      v0.18.2 (voir *La normalisation du serveur*)
- [ ] Event `DriftCorrected` et compteur `remote_writes_total` (D4, D6) :
      il faut que `ReconcileOutcome` porte la dérive. En attendant, chaque
      correction est journalisée (`drift corrected`, avec les champs).
- [ ] test de contrat contre un Authentik 2026.8 : deux réconciliations,
      zéro événement `model_updated` au second passage

**weebo-si**

- [x] montée de version de l'opérateur en 0.18.2 (`44f873e5`). Premier
      constat : les 16 CR sont Ready, aucune erreur, et seuls les 3
      ScopeMappings sont réécrits à chaque cycle
- [ ] validation complète (*Exploitation*), une fois `expression` corrigée
- [ ] décider du sort des palliatifs ; left-todo à jour

## Références

- weebo-authentik v0.18.1 :
  `crates/adapters-outbound/src/authentik_http/{applications,providers,policy_bindings,groups,users,brands,flows,scope_mappings,outposts}.rs`
  (PATCH sans comparaison), `crates/application/src/use_cases/reconcile_application.rs`
- weebo-forgejo : `crates/application/src/use_cases/mod.rs` (`differs`,
  `differs_flag`), `reconcile_organization.rs`
  (`creates_then_stays_quiet_until_drift`)
- weebo-operator-kit v0.17.0 :
  `templates/operator/crates/application/src/use_cases/reconcile_object.rs`,
  `crates/weebo-kit-runtime/src/controller.rs` (`STEADY_REQUEUE_SECS`)
- weebo-authentik v0.18.2 : `crates/domain/src/drift.rs` (l'API reprise par
  le kit), `crates/adapters-outbound/src/authentik_http/shared.rs`
  (`must_write`)
- Authentik 2026.8 : `/authentik/lib/default.yml` (`worker.task_expiration`),
  `django_dramatiq_postgres/broker.py` (`_auto_purge`), table
  `authentik_tenants_tenant.event_retention`
- [RFC 0001](/docs/rfc/0001-stalwart) : la réconciliation des comptes
  Stalwart suit ce modèle

## Changelog

| Date | Changement |
| --- | --- |
| 2026-10-18 | Brouillon initial, après la mesure faite pendant la migration CNPG d'Authentik |
| 2026-10-18 | Implémenté dans weebo-authentik (branche `fix/write-only-what-drifts`) : comparaison dans l'adaptateur, brand corrigée ; Event et compteur reportés ; Q3 et Q5 (brand) tranchées |
| 2026-10-18 | v0.18.2 déployée. Le kit reprend l'API livrée (`Drift::keep*`, `same_set`, `same_subset`) au lieu des `differs*` proposés, et y ajoute `Drift::note` et `same_trimmed`. Nouvelle section *La normalisation du serveur*, après la dérive permanente des `expression` de ScopeMapping ; alerte proposée ; plan découpé en kit puis opérateurs |
