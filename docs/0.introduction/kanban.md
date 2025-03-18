# Kanban

```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://github.com/batleforc/weebo-si/issue/#TICKET#'
---

kanban
  todoS[To Do On Stream]
    us4[Nuke le Proxmox et automatisé la configuration réseau DHCP]@{ assigned: Post-Nuke, priority: 'Low'}
    us5[Créer le cluster CAPI avec un CloudInit]@{ assigned: Post-Nuke, priority: 'Low'}
    us6[Passer les cluster sous cilium]@{ assigned: Post-Nuke, priority: 'Low'}
  todo[To Do]
    us7[Exposer dashboard Traefik]@{ assigned: Pre-Nuke, priority: 'High'}
    use8[Check if HeadLamp can be used to access dynamically each cluster]@{ assigned: Pre-Nuke, priority: 'High'}
    us3[Définir les règles de sécurité pour les clusters]@{ assigned: Pre-Nuke, priority: 'High'}
    us8[Définir les règles d'identité]@{ assigned: Pre-Nuke, priority: 'High'}
    us7[Gestion PKI partagé avec DNS bind9]@{ assigned: Post-Nuke, priority: 'Low'}
  doing[Doing]
  done[Done]
    us1[Créer un cluster multi master self schedulable]
    us2[Déployer Traefik et CertManager sur tous les clusters via ArgoCD]
```

- [Talos Kubernetes configuration](https://www.talos.dev/v1.9/reference/configuration/v1alpha1/config/)

## Stream

### Stream 15 mars 2025

- Debut : 17h10
- FIN : ~19h00 ?
- Vod : [Twitch](https://www.twitch.tv/videos/2406435027) YouTube : Soon
- Musique: [Chillhop](https://app.chillhop.com/)
- Objectif :
  - Présenté le projet
  - Terminer la configuration du cluster multi master self schedulable
  - Déployer Traefik et CertManager sur tous les clusters via ArgoCD
- Bilan
  - [Headlamp injection](https://headlamp.dev/docs/latest/installation/in-cluster/#exposing-headlamp-with-an-ingress-server)
  - [Headlamp Oidc](https://headlamp.dev/docs/latest/installation/in-cluster/oidc/)
  - Task board mis a jour

## Music

- [Chillhop](https://app.chillhop.com/)<= Plus calme
- [NCS](https://ncs.io/) <= Plus rythmé et varié (Pas encore testé)
