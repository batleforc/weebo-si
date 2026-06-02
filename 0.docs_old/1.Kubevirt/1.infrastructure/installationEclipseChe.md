# Installation d'Eclipse Che sur KubeVirt

## Objectif

- Créer un cluster dédié à Eclipse Che sur KubeVirt

## Prérequis

- Avoir un cluster Talos fonctionnel (par exemple en suivant le [guide Weebo-SI](./initOvhTalos.md)) ou un sous-cluster KubeVirt x Talos opérationnel (par exemple en suivant le [guide Weebo-SI](./installationKubevirt.md)).
- Avoir les briques suivantes :
  - [Cert Manager](https://cert-manager.io/docs/)
  - [Ingress Controller](https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/), par exemple [Traefik](https://doc.traefik.io/traefik/)
  - Un fournisseur OIDC (par exemple [Authentik](https://goauthentik.io/docs/))
- Et optionnellement :
  - [Vault](https://www.vaultproject.io/) pour le stockage des secrets et l'industrialisation du déploiement
  - [Harbor](https://goharbor.io/) pour la gestion des images de conteneurs
