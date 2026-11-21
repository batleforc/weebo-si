# Documentation : de quoi réfléchir

Préparé le 2026-11-21 à partir de la section Documentation de `left-todo.md`,
de la revue et des pièges notés au fil des sessions. Le but : décider la
forme avant d'écrire, pas cocher des pages.

## 1. Les questions à trancher d'abord

1. **Pour qui ?** Trois lecteurs différents, qui ne cherchent pas la même
   chose :
   - le dev qui arrive : comment j'obtiens un workspace et je pousse du code ;
   - l'admin (toi aujourd'hui, quelqu'un d'autre demain) : comment je
     réinstalle, je redémarre, je restaure, je débloque ;
   - le relecteur sécurité : quelles barrières existent, où, et ce qu'elles
     ne couvrent pas.
2. **Quelle langue ?** Les pages mélangent français et anglais, les
   commentaires des charts sont en anglais. Choisir une règle (par exemple :
   docs en français, code et commentaires en anglais) et s'y tenir.
3. **Où vit le « pourquoi » ?** Il est aujourd'hui surtout dans les
   commentaires des `values.yaml`, très riches. Les dupliquer dans la doc,
   c'est deux versions qui divergent. Piste : la doc donne la carte et les
   liens, le `values.yaml` garde le détail.
4. **Généré ou écrit à la main ?** `task docs:netflow` et `task docs:authflow`
   montrent que la génération marche. Candidats : inventaire des applications
   (chart, version, namespace, projet Argo) depuis `2.argo/app`, carte des
   features du hardening et de leur mode (Off/DryRun/Enforce), liste des
   webhooks `Fail` et de leurs sélecteurs (utile avant chaque reboot).
5. **`left-todo.md` : feuille de route ou journal ?** Il fait les deux, avec
   des dates et des détails d'incident. Piste : la feuille de route reste
   courte, les détails partent dans les runbooks (section journal) ou les RFC.
6. **Comment savoir qu'une page est périmée ?** Date de dernière vérification
   par page, ou génération au pre-commit comme netflow.

## 2. Guides (manquants)

### Guide d'installation (admin)

- Du serveur OVH vide au cluster : `1.pulu-init` (Talos, Cilium), puis
  `1.pulu-conf` (Argo CD), puis l'app of apps, puis `2.terra` (Vault,
  Authentik).
- Les variables de `.env` et d'où elles viennent (dont `ADMIN_CIDRS`,
  obligatoire depuis le 2026-11-21).
- Le bootstrap des secrets (OpenBao, clés d'unseal, root token) et ce qui
  n'est pas dans Git (rétention des événements Authentik réglée en base).
- Accès de secours : kubeconfig admin, talosconfig, chemin Netbird.

### Guide utilisateur (dev)

- Prérequis : Netbird, compte Authentik, groupes.
- Premier workspace Che, éditeurs disponibles, dotfiles.
- Git : Forgejo interne, sign in with Forgejo, miroirs GitHub.
- Registres : angos (`docker login`, page `/me/`), batlehub (npm, cargo, go).
- kubectl en OIDC depuis un workspace.
- Ce qui est interdit et pourquoi (imagePolicy, networkProfiles, PSA,
  KubeArmor), avec les messages d'erreur qu'on voit.

## 3. Vues d'ensemble (manquantes)

- **Sécurité** : la plus utile à écrire. Une carte par couche :
  - périmètre : pare-feu Talos, CNP devant Traefik, VPN, RFC 0006 ;
  - identité : Authentik, Dex, RBAC, groupes ;
  - workload : PSA, KubeArmor, Kyverno, imagePolicy, endpointAuth ;
  - réseau : les vagues de default deny, entrée puis sortie ;
  - chaîne d'approvisionnement : miroirs angos, scan trivy, Renovate,
    signature (à venir) ;
  - données : Vault, sauvegardes, ce qui n'est pas sauvegardé.

  Pour chaque couche, écrire aussi ce qu'elle ne couvre pas.
- **Environnement de dev** : Che, hardening, workspaces, et les pistes de
  `todo/dev-env.md`.

## 4. Référence par composant (liste existante de `left-todo.md`)

La liste « Macro Infra / Database / Monitoring / Registry / Security / Dev
Environment » de `left-todo.md` reste valable. Ce qui manque sur chaque page
pour qu'elle serve vraiment :

- le rôle en une phrase, et qui en dépend (au démarrage notamment) ;
- où est la config (chart, values, Pulumi, terraform) ;
- comment on vérifie qu'il marche ;
- les pièges connus (section suivante) ;
- le lien vers le runbook de restauration ou d'upgrade.

## 5. Pièges connus à sortir des têtes et des notes

Ces points sont aujourd'hui dans des commentaires épars ou des notes de
session. Ce sont ceux qui coûtent le plus cher quand on les oublie :

- Pulumi : ne jamais faire de `refresh` sur `1.pulu-init` (schematic IDs,
  `reinstallTalos`) ; un `up` qui touche `machine.files` redémarre le nœud ;
  `cilium-values.yaml` est la release entière (une clé absente disparaît).
- Talos : etcd ne relit ses `extraArgs` qu'au reboot ; `talosctl upgrade`
  sans `--drain=false` reste bloqué sur les PDB ; la config d'auth de
  l'apiserver n'est validée strictement qu'au démarrage (`dyn(claims.groups)`).
- Démarrage : chaîne d'admission vault-infra → hook (kyverno) → le reste ;
  Che peut démarrer avant Dex et rester non prêt.
- Argo CD : `operation.sync` ignore les syncOptions de l'app ; pas de `prune`
  sur l'app racine.
- Authentik : `mode=proxy` par défaut des forward-auth ; fuite `/dev/shm`
  ralentie, pas corrigée.
- Réseau : l'IP vue pour un peer Netbird est celle du pod exit-node, donc
  `ipAllowList` ne veut pas dire « utilisateur VPN ».
- SELinux / Longhorn : le flood d'audit vient des volumes `unlabeled_t`.

## 6. Décisions

- Les RFC existent et sont bien tenues. Manque un index des décisions plus
  petites (pourquoi deux Traefik, pourquoi pas d'automerge Renovate, pourquoi
  le root token reste stocké dans ce lab) : une ligne chacune, avec un lien.
