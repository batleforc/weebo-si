# Kamalos

Le projet Kamalos a pour but de tester et expérimenter Kamaji en tant que control plane pour un cluster Talos. Cette XP est issue de la création du projet Github [Talos CSR Signer](https://github.com/clastix/talos-csr-signer) qui permet de gérer les CSR Talos via un sidecar dans le control plane Kamaji ainsi que de la vidéo [Kamaji x Talos](https://www.youtube.com/watch?v=nSGo_72LnmY) de la chaine YouTube Clastix.

Cette XP a commencer lors du stream du 15 Novembre 2025 et est toujours en cours. Le cadre de cette XP est le suivant:

- Un cluster Talos avec Kubevirt/Kamaji/Cluster API
- Un control plane Kamaji avec le sidecar Talos CSR Signer
- Des workers Talos sous forme de machines virtuelles Kubevirt OU un possible worker container (a tester)
- Tester si la Cluster API peut s'intégrer en l'état avec ce workflow
- Bien sur, valider l'usage de briques de base comme:
  - ArgoCD
  - Cilium
  - Grafana x Coroot
  - Kubevirt CSI

## Setup non automatisé

Le setup qui suit n'est pas automatisé et grandement basé sur le tutoriel bootstrap side car de [le tutoriel bootstrap side car de Talos CSR Signer](https://github.com/clastix/talos-csr-signer/blob/master/docs/sidecar-deployment.md)

### Prérequis

- Un cluster Kubernetes "Hôte" avec:
  - Kubevirt
  - ArgoCD
  - Cilium
- Un poste avec:
  - kubectl
  - talosctl
  - kubeadm
  - helm 3
  - task (optionnel, pour exécuter les commandes dans le cluster hôte)
  - Un accès directe dans le réseau Kubernetes (via un VPN ou un kubectl port-forward par exemple)
- Le repository git [Weebo-SI](https://github.com/batleforc/weebo-si) cloné et être dans le dossier `all-in-one.argo/helm/kamalos`

::: tip

Les scripts fournis utilisent la commande `task aio:kubectl --` pour exécuter les commandes kubectl dans le cluster HOST. Il est possible d'adapter les scripts en remplaçant cette commande par `kubectl --kubeconfig=./path/to/kubeconfig` si vous souhaitez exécuter les commandes directement.

:::

::: warning

L'exécution de la suite part du principe que vous avez un accès réseau direct au cluster Kubernetes hôte (via un VPN ou en étant directement sur le réseau).

Dans le cas contraire, il est possible d'adapter les scripts pour utiliser des port-forward kubectl ou autre méthode.

:::

### Installation

#### 1. Création des secrets

Avant de déployer Kamaji il est nécessaire de préparer les secrets nécessaires en créant une configuration Talos puis en créant le secret dans kubernetes.

```bash
talosctl gen secrets -o ./tmp/secrets.yaml --force # Génère la configuration Talos
./secret.sh # Créer le secret correspondant dans le namespace kamalos
```

WIP: Suite de l'installation à venir...

## Setup with VPN

### Goal

- Un control plane Kamaji avec le sidecar Talos CSR Signer sur Weebo-SI
- Un worker Kubevirt Talos sur Weebo-SI
- Un worker VM ou Docker Talos sur le poste local (via VPN)
- Un VPN Netbird avec un "réseau" partager entre le cluster hôte et le noeud (pas de vpn sur le poste local !)