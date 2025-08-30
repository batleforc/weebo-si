# Kanban

```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://github.com/batleforc/weebo-si/issue/#TICKET#'
---

kanban
  todo[To Do]
    us203[Try to fix proxmox with the csi driver]@{ assigned: Proxmox, priority: 'High'}
    us204[Refaire les règle UpdateCLI]@{ assigned: RÉCURENT, priority: 'High'}
    us205[Recréer l’autorité de certification uniquement via terraform]@{ assigned: MVP1, priority: 'High'}
    us206[Mise en place d'une stack de Monitoring (Log/Trace/Métrique)]@{ assigned: MVP1, priority: 'High'}
    us207[Mise en place Harbor et propagation dans les clusters pour avoir un cache des images]@{ assigned: MVP1, priority: 'High'}
    us208[Mise en place d'une extensions Netbird pour Talos]@{ assigned: MVP1, priority: 'High'}
    us209[Mise en place et développement d'un ProxyApiKube]@{ assigned: MVP2, priority: 'High'}
    us210[Tester un autre provider de cluster que Talos dans Kubevirt]@{ assigned: MVP2, priority: 'High'}
    us211[Mettre en place KASM x KubeVirt]@{ assigned: MVP2, priority: 'High'}
    us212[Mise en place ContainerSSH]@{ assigned: MVP2, priority: 'High'}
    us213[Mise en place Bastion WarpGate]@{ assigned: MVP2, priority: 'High'}
    us214[Mise en place Headlamp pour les sous cluster]@{ assigned: MVP2, priority: 'High'}
  doing[Doing]
  done[Done]
    us201[Lister les application a intégrer PROPREMENT]@{ assigned: MVP, priority: 'High'}
    us202[Définir le programme des prochains mois]@{ assigned: MVP, priority: 'High'}
```

- [WarpGate](https://warpgate.null.page/docs/)

## Actions récurrentes

- Vérifier les [MR](https://github.com/batleforc/weebo-si/pulls?q=is%3Aopen+is%3Apr+label%3AUpdateCLI) de mise a jour toute les semaines

## Stream

- [Playlist Twitch](https://www.twitch.tv/collections/Gha3LW0WLRh8hg)
- [Playlist YouTube](https://youtube.com/playlist?list=PLgGm8OmIPBhnlGhLG4RhUXV8zUvBmvl-O&si=dIglK5lVrDIImCQo)

### Stream 30 AOÛT 2025 - SAISON 2222222222

- Debut : 16h30
- FIN : ~ 18H30 - Petit stream I'm BACK !
- Vod : [Twitch](https://www.twitch.tv/batleforc) YouTube : Soon
- Musique: [NCS](https://ncs.io/)
- Objectif
  - Regarde le kanban 🤣
  - Psttt fin du MVP et début du suivant !!!

### [Bilan des streams de la saison 2](/0.introduction/stream/saison2/index.html) - In Progress

### [Bilan des streams de la saison 1](/0.introduction/stream/saison1/index.html) - Finalisé

## Music

- [Chillhop](https://app.chillhop.com/)<= Plus calme
- [NCS](https://ncs.io/) <= Plus rythmé et varié (Pas encore testé)
