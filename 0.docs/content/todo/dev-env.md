# Environnement de dev : notes pour plus tard

Notes du 2026-11-21, issues de la revue. Rien n'est décidé ici : ce sont les
pistes à reprendre, avec ce qu'on sait déjà.

## CI/CD interne

- Forgejo Actions sur `git.weebo.poc`, runner (`act_runner`) dans le cluster.
- Débloquerait aussi l'OIDC CI d'angos sans exposer le registre (les runners
  GitHub ne le joignent pas, RFC 0006 §3.1), et donnerait un endroit où faire
  tourner la validation des manifestes (point 8 de la revue).
- Un runner exécute du code non relu : namespace dédié, runners éphémères,
  aucun secret pour les PR de fork, egress limité à angos/batlehub/forgejo.
- Le runner ne doit pas construire les images lui-même (pas de dind) : il
  appelle le builder central (section suivante).
- À vérifier : ce que Forgejo Actions sait faire en jetons OIDC pour les jobs
  (équivalent de `id-token: write`), sinon angos/batlehub ne peuvent pas
  authentifier un push sans secret long.

## Build d'images : podman dans le workspace, ou BuildKit central + kubedock ?

Aujourd'hui, `podSecurity` est en `baseline` et le commentaire du hardening
prévoit un profil seccomp de build posé par la DWOC pour podman/buildah dans
le workspace.

### Podman/buildah dans le workspace

- Chaque workspace devient un builder : capacités et seccomp élargis partout,
  y compris pour ceux qui ne buildent jamais.
- Cache par workspace (perdu à l'arrêt, dupliqué entre utilisateurs).
- Pics CPU/mémoire dans le quota du workspace (`resourceQuotas` pas encore
  actif).
- Simple pour l'utilisateur, aucune brique à opérer.

### BuildKit central pour le build, kubedock pour le run

- Les workspaces restent sans capacité de build : on pourrait viser
  `restricted` plutôt que `baseline` (à vérifier avec kubedock).
- kubedock traduit l'API docker en pods dans le namespace du workspace : les
  conteneurs lancés héritent de PSA, des CiliumNetworkPolicies, de KubeArmor
  et d'imagePolicy. Il ne construit rien, d'où le besoin du builder.
- BuildKit (`buildkitd` rootless) dans un namespace `build`, joint par
  `docker buildx` avec le driver `remote` en mTLS :
  - cache partagé, exporté vers angos (`--cache-to type=registry`) ;
  - egress du builder limité à angos/batlehub (même logique que imagePolicy :
    pas d'Internet direct) ;
  - SBOM et provenance générés au même endroit (`--attest`), ce qui prépare
    la signature d'images (point 8) ;
  - un seul endroit pour la politique : push vers angos uniquement.
- Les risques à traiter avant :
  - un `buildkitd` partagé entre utilisateurs, c'est du multi-tenant : cache
    empoisonné, secrets de build (`--secret`) visibles du daemon. Piste : un
    `buildkitd` par équipe (WeeboSiTeam), ou des pods de build éphémères
    lancés par un contrôleur ;
  - l'auth : un certificat client par utilisateur (cert-manager), délivré
    par le hardening comme les autres features ? Ou un proxy authentifiant
    devant le daemon ;
  - rootless BuildKit demande des user namespaces et un seccomp/AppArmor
    moins strict (`--oci-worker-no-process-sandbox` sinon) : il faut le
    confiner, lui, par KubeArmor et ses propres CNP.
- Alternatives à garder en tête : buildah en Job éphémère par build (isolement
  fort, pas de cache partagé) ; kaniko est en maintenance depuis 2025 (fork
  Chainguard).

Avis de la revue : BuildKit central + kubedock est meilleur pour la sécurité
que podman dans chaque workspace, à condition de ne pas partager un daemon
entre équipes.

## Stalwart

- RFC 0001 (opérateur weebo-stalwart) et RFC 0002 (brique de liaison
  `link.weebo.io/stalwart`).
- `mail-pg` n'est pas sauvegardé, à ajouter à `weebo-base.cnpgBackup` quand
  Stalwart sert vraiment.
- Le détail des étapes est dans `left-todo.md` (section Stalwart).
