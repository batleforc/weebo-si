# Capi Vs Omni

- Date du stream : 02 / 07 / 2025
- [Twitch](https://www.twitch.tv/batleforc)
- Playlist
  - [Twitch](https://www.twitch.tv/collections/Gha3LW0WLRh8hg)
  - [Youtube](https://youtube.com/playlist?list=PLgGm8OmIPBhnlGhLG4RhUXV8zUvBmvl-O)

## Goal

Comparer dans des condition similaire [Omni](https://omni.siderolabs.com/) et [ClusterAPI](https://cluster-api.sigs.k8s.io/). L'objectif est d'obtenir un cluster Kubernetes basé sur Talos.

- Talos : v1.10.5
- Kubernetes: v1.33
- Moteur de virtualisation: KubeVirt
- Configuration:
  - Mono Node
    - 1 Control Plane / Worker
      - CPU: 4
      - RAM: 32Gi
  - Multi Node - Si on a le temps
    - 2 Control Plane
    - 1 Worker
- CNI : [Cilium](https://cilium.io/)
- CSI (A choisir)
  - MainCluster
    - [Local Path Provisioner](https://github.com/rancher/local-path-provisioner)
    - [LongHorn](https://longhorn.io/)
    - [Rook ?](https://rook.io/)
  - SubCluster
    - [Kubevirt CSI](https://github.com/kubevirt/csi-driver)
    - [Rook ?](https://rook.io/)

## Feature a déployer

- [CertManager](https://cert-manager.io/)
  - Vault Certificate (OPT)
  - Lets Encrypt
- [Traefik](https://traefik.io/traefik)
  - 1 Sous DNS par cluster
    - *.[Cluster NAME].cluster.4.weebo.fr
- [Game Server](https://github.com/awesome-selfhosted/awesome-selfhosted#games)

## Lien

- <https://cidr.xyz/>
