# Kanban

```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://batleforc.github.io/weebo-si/0.us/#TICKET#'
---

kanban
  todo[To Do]
    us203[Try to fix proxmox with the csi driver]@{ assigned: Proxmox, priority: 'High'}
    us204[Refaire les règle UpdateCLI]@{ assigned: RÉCURENT, priority: 'High'}
    us216[Mise en place NetPolicy]@{ assigned: MVP1, priority: 'High', ticket: 'us216'}
    us205[Recréer l’autorité de certification uniquement via terraform]@{ assigned: MVP1, priority: 'High'}
    us210[Tester un autre provider de cluster que Talos dans Kubevirt]@{ assigned: MVP2, priority: 'High'}
    us211[Mettre en place KASM x KubeVirt]@{ assigned: MVP2, priority: 'High'}
    us212[Mise en place ContainerSSH]@{ assigned: MVP2, priority: 'High'}
    us213[Mise en place Bastion WarpGate]@{ assigned: MVP2, priority: 'High'}
    us214[Mise en place Headlamp pour les sous cluster]@{ assigned: MVP2, priority: 'High'}
    us215[Mise en place d'un S3, RustFS ?]@{ assigned: MVP2, priority: 'High'}
    us217[Mise en place d'environnement Eclipse che - par ex nix]@{ assigned: MVP3, priority: 'High'}
  doing[Doing]
    us206[Mise en place d'une stack de Monitoring, Log/Trace/Métrique]@{ assigned: MVP1, priority: 'High', ticket: 'us206'}
    us208[Mise en place d'une extensions Netbird pour Talos]@{ assigned: MVP1, priority: 'High'}
    us209[Mise en place et développement d'un ProxyApiKube]@{ assigned: MVP2, priority: 'High'}
  done[Done]
    us201[Lister les application a intégrer PROPREMENT]@{ assigned: MVP, priority: 'High'}
    us202[Définir le programme des prochains mois]@{ assigned: MVP, priority: 'High'}
    us207[Mise en place Harbor et propagation dans les clusters pour avoir un cache des images]@{ assigned: MVP1, priority: 'High'}
```

- [WarpGate](https://warpgate.null.page/docs/)
- [Grafana MCP](https://github.com/grafana/helm-charts/tree/main/charts/grafana-mcp)
- [Coroot Grafana Dashboards](https://github.com/kirillyu/coroot-grafana-dashboards)

## Bazar d'actions

- Tester l'Install de Talos via ISO ephemeral
- Travaux monitoring (voir us206)

## Actions récurrentes

- Vérifier les [MR](https://github.com/batleforc/weebo-si/pulls?q=is%3Aopen+is%3Apr+label%3AUpdateCLI) de mise a jour toute les semaines

## Stream

- [Playlist Twitch](https://www.twitch.tv/collections/Gha3LW0WLRh8hg)
- [Playlist YouTube](https://youtube.com/playlist?list=PLgGm8OmIPBhnlGhLG4RhUXV8zUvBmvl-O&si=dIglK5lVrDIImCQo)

### Stream 11 OCTOBRE 2025

- Debut : 16h30
- FIN : ~ 18h30
- Vod : [Twitch](https://www.twitch.tv/batleforc) YouTube : Soon
- Musique: [NCS](https://ncs.io/)
- Objectif
  - Retour Netbird x Talos
    - Mise en place de la configuration Isolated Network
  - UserNamespace ?
    - Nested podman/docker ?
    - Industrialisation du build des images Talos
  - Retour [ProxyAuthK8S](https://github.com/batleforc/ProxyAuthK8S)
    - Avancement
    - Stocker les cluster dans Redis pour aller plus vite
    - Comprendre pourquoi les event ne sont pas attacher au Trace

### Stream 27 SEPTEMBRE 2025

- Debut : 16h30
- FIN : ~ 18h30
- Vod :
  - Twitch
    - [1/3](https://www.twitch.tv/videos/2577116098)
    - [2/3](https://www.twitch.tv/videos/2577151005)
    - [3/3](https://www.twitch.tv/videos/2577153148)
  - YouTube : Soon
- Musique: [NCS](https://ncs.io/)
- Objectif
  - Ajouter au Sous Cluster Talos l'extensions [Netbird](https://github.com/siderolabs/extensions/tree/main/network/netbird)
    - Build de l'image ?!
    - Stockage de l'iso dans un S3 (RustFS ?!)
  - Chargement des métriques Traefik ++ envoie des traces Traefik vers OTEL Collector
  - Déployer [kubevirt operator](https://github.com/seatgeek/buildkit-operator)
  - Ajout d'une auth Authentik dans Vault
  - Retour stream CuistOps x Kubevirt x Capi x Talos x Cilium
    - Réseau
      - Cilium x Tunneling x Plage CIDR invalide
      - [Netbird x Talos](https://github.com/siderolabs/extensions/tree/main/network/netbird) (Not Tailscale xD)
    - Stockage
      - [Longhorn x Talos](https://github.com/longhorn/longhorn/pull/11199)

### Stream 20 SEPTEMBRE 2025

- Debut : 16h30
- FIN : ~ 18h30
- Vod : [Twitch](https://www.twitch.tv/videos/2571232605) [YouTube](https://youtu.be/_7REED7ysOA)
- Musique: [NCS](https://ncs.io/)
- Objectif
  - KubeApiProxy ?!
    - Parler des spec
    - Initialiser le projet
  - Chargement des métriques Traefik ++ envoie des traces Traefik vers OTEL Collector
  - Préparation de l'auto scaling des clusters Talos pour [lundi 22 SEPTEMBRE 2025](https://www.twitch.tv/cuistops)
  - Déployer [kubevirt operator](https://github.com/seatgeek/buildkit-operator)
  - Ajout d'une auth Authentik dans Vault
- Bilan
  - KubeApiProxy ?! and only kubeApiProxy

### Stream 13 SEPTEMBRE 2025

- Debut : 16h30
- FIN : ~ 18h30
- Vod : [Twitch](https://www.twitch.tv/videos/2565416116) [YouTube](https://youtu.be/1aH1YR0tBY4)
- Musique: [NCS](https://ncs.io/)
- Objectif
  - Pas MERCI CuistOps, Du GitOps dans nos VM ?!
    - Discussions autour du contexte
    - Comment le mettre en place ?
    - Boot-C x Cloud Init ?
  - KubeApiProxy ?!
  - déploiement OTEL
  - Chargement des métriques Traefik ++ envoie des traces Traefik vers OTEL Collector

### Stream 6 SEPTEMBRE 2025

- Debut : 16h30
- FIN : ~ 19h30
- Vod : [Twitch](https://www.twitch.tv/videos/2559647271) [YouTube](https://youtu.be/njCye6LxTE0)
- Musique: [NCS](https://ncs.io/)
- Objectif
  - On attaque la mise en place de la stack de monitoring !
    - Grafana ++ sidecar load source && dashboard
    - déploiement OTEL
    - Chargement des métriques Traefik ++ envoie des traces Traefik vers OTEL Collector
- Bilan
  - KubeApiProxy ?! : Next Time
  - Upgrade ArgoCD : DONE
  - Mise en place Grafana x Coroot : DONE
  - Next Step: Créer des dashboards Grafana pour coroot : DONE

### [Bilan des streams de la saison 2](/0.introduction/stream/saison2/index.html) - In Progress

### [Bilan des streams de la saison 1](/0.introduction/stream/saison1/index.html) - Finalisé

## Music

- [Chillhop](https://app.chillhop.com/)<= Plus calme
- [NCS](https://ncs.io/) <= Plus rythmé et varié (Pas encore testé)
