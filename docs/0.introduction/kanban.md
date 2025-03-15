# Kanban

```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://github.com/batleforc/weebo-si/issue/#TICKET#'
---

kanban
  todo[To Do]
    us7[Exposer dashboard Traefik]@{ assigned: Pre-Nuke, priority: 'High'}
    use8[Check if HeadLamp can be used to access dynamically each cluster]@{ assigned: Pre-Nuke, priority: 'High'}
    us3[Définir les règles de sécurité pour les clusters]@{ assigned: Pre-Nuke, priority: 'High'}
    us4[Nuke le Proxmox et automatisé la configuration réseau DHCP]@{ assigned: Post-Nuke, priority: 'Low'}
    us5[Créer le cluster CAPI avec un CloudInit]@{ assigned: Post-Nuke, priority: 'Low'}
    us6[Passer les cluster sous cilium]@{ assigned: Post-Nuke, priority: 'Low'}
    us7[Gestion PKI partagé avec DNS bind9]@{ assigned: Post-Nuke, priority: 'Low'}
  doing[Doing]
  done[Done]
    us1[Créer un cluster multi master self schedulable]
    us2[Déployer Traefik et CertManager sur tous les clusters via ArgoCD]
```

## Stream 15 mars 2025

- Debut : 17h10
- FIN : ~19h00 ?
- Objectif :
  - Présenté le projet
  - Terminer la configuration du cluster multi master self schedulable
  - Déployer Traefik et CertManager sur tous les clusters via ArgoCD
- Bilan
  - [Headlamp injection](https://headlamp.dev/docs/latest/installation/in-cluster/#exposing-headlamp-with-an-ingress-server)
  - [Headlamp Oidc](https://headlamp.dev/docs/latest/installation/in-cluster/oidc/)
  - Task board mis a jour
