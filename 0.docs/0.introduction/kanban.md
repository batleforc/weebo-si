# Kanban

```mermaid
---
config:
  kanban:
    ticketBaseUrl: 'https://github.com/batleforc/weebo-si/issue/#TICKET#'
---

kanban
  todoS[To Do On Stream]
  todo[To Do]
    us3[Définir les règles de sécurité pour les clusters]@{ assigned: Pre-Nuke, priority: 'High'}
    us7[Gestion PKI partagé avec DNS bind9]@{ assigned: Post-Nuke, priority: 'Low'}
    use10[Setup Cilium V6 et V4 pour les LoadBalancer]@{ assigned: Post-Nuke, priority: 'Low'}
    us11[Comparer Falco et Tetragon]@{ assigned: Post-Nuke, priority: 'Low'}
    us14[Déployer Dex sur tous les clusters via ArgoCD]@{ assigned: Post-Nuke, priority: 'Low'}
  doing[Doing]
    use12[Centraliser l'authentification et l'appliquer au différent service]@{ assigned: Post-Nuke, priority: 'Low'}
    us8[Définir les règles d'identité]@{ assigned: Pre-Nuke, priority: 'High'}
    us16[Autorité de certification]@{ assigned: Post-Nuke, priority: 'Low'}
    use17[Déployer OpenUnison sur tous les clusters via ArgoCD]@{ assigned: Post-Nuke, priority: 'Low'}
    us18[Déployer WarpGate sur tous les clusters via ArgoCD]@{ assigned: Post-Nuke, priority: 'Low'}
  done[Done]
    us7[Exposer dashboard Traefik]@{ assigned: Pre-Nuke, priority: 'High'}
    us1[Créer un cluster multi master self schedulable]
    us2[Déployer Traefik et CertManager sur tous les clusters via ArgoCD]
    us9[Mettre en place updatecli]@{ assigned: Post-Nuke, priority: 'Low'}
    us13[Hardening SSH]@{ assigned: Pre-Nuke, priority: 'High'}
    use8[Check if HeadLamp can be used to access dynamically each cluster]@{ assigned: Pre-Nuke, priority: 'High'}
    us15[Faire une gestion DNS avec alias dynamique]@{ assigned: Post-Nuke, priority: 'Low'}
    us4[Nuke le Proxmox et automatisé la configuration réseau DHCP]@{ assigned: Post-Nuke, priority: 'Low'}
    us5[Créer le cluster CAPI avec un CloudInit]@{ assigned: Post-Nuke, priority: 'Low'}
    us6[Passer les cluster sous cilium]@{ assigned: Post-Nuke, priority: 'Low'}
```

- [Talos Kubernetes configuration](https://www.talos.dev/v1.9/reference/configuration/v1alpha1/config/)
- [Terraform Cilium](https://registry.terraform.io/providers/littlejo/cilium/latest/docs/resources/cilium) plus jamais d'install manuelle !!!
- [Paralus](https://www.paralus.io/docs/Installation/) [ParalusTF](https://registry.terraform.io/providers/iherbllc/paralus/latest/docs)
- [OpenUnison](https://openunison.github.io/)
- [Falco rules](https://une-tasse-de.cafe/blog/falco/)
- [Dex](https://dexidp.io/)
- [WarpGate](https://warpgate.null.page/docs/)
- [Kyverno Reporter](https://kyverno.github.io/policy-reporter-docs/getting-started/installation.html)

## Actions récurrentes

- Nuke le Proxmox tout les 2 mois
  - last update : 19-04-2025
  - next update : 19-06-2025
- Vérifier les [MR](https://github.com/batleforc/weebo-si/pulls?q=is%3Aopen+is%3Apr+label%3AUpdateCLI) de mise a jour toute les semaines

## Stream

- [Playlist Twitch](https://www.twitch.tv/collections/Gha3LW0WLRh8hg)
- [Playlist YouTube](https://youtube.com/playlist?list=PLgGm8OmIPBhnlGhLG4RhUXV8zUvBmvl-O&si=dIglK5lVrDIImCQo)

### Stream 17 mai 2025 - In Progress

- Debut : 16h30
- FIN : ~ 18H30
- Vod : [Twitch](https://www.twitch.tv/batleforc) YouTube : SOON TM
- Musique: [NCS](https://ncs.io/)
- Objectif (Pas dans l'ordre):
  - Explorer la mise en place de secrets
    - [Try ArgoCD Vault](https://argocd-vault-plugin.readthedocs.io/en/stable/installation/)
    - <https://external-secrets.io/latest/>
    - <https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso>
    - <https://bank-vaults.dev/docs/mutating-webhook/>
  - Déployer un driver CSI ([Longhorn](https://www.talos.dev/v1.10/kubernetes-guides/configuration/storage/) ?) !
  - Configurer Authentik via une approche [GitOps](https://registry.terraform.io/providers/goauthentik/authentik/latest/docs)
    - [Bootstrap](https://docs.goauthentik.io/docs/install-config/automated-install)
    - [ArgoCD](https://docs.goauthentik.io/integrations/services/argocd/)
- Sujet
  - [Anubis](https://anubis.techaro.lol/)
- Bilan

### Stream 10 mai 2025

- Debut : 16h30
- FIN : ~ 19H30
- Vod : [Twitch 1](https://www.twitch.tv/videos/2455229336) [Twitch 2](https://www.twitch.tv/videos/2455248428) [YouTube 1](https://youtu.be/IxlazbMlPrE) [YouTube 2](https://youtu.be/X1O9Af9SCns)
- Musique: [NCS](https://ncs.io/)
  - [NCS: The Best of 2025 ⚡️](https://www.youtube.com/playlist?list=PLRBp0Fe2GpgkDw2aMG2lM5heA8cbLvOoN)
- Objectif (Pas dans l'ordre):
  - Automatiser la mise en place de l'autorité de certification RootCA / IntermediateCA via [Bank Vaults](https://bank-vaults.dev/). :white_check_mark: Passage en conf 100% Terraform ?
  - Automatiser la création de certificats via le DNS01 ❎ et HTTP01 :white_check_mark:
  - Trust le RootCA sur mon ordinateur et [le propager sur les clusters](https://github.com/cert-manager/trust-manager) tout en l'injectant dans les pods via [Kyverno](https://kyverno.io/policies/other/add-certificates-volume/add-certificates-volume/) :white_check_mark: Mode OPT-IN
  - Déployer un Auth Provider sur Main Cluster  :white_check_mark: mais avec le local storage !
  - [Try ArgoCD Vault](https://argocd-vault-plugin.readthedocs.io/en/stable/installation/) :warning: pour la prochaine fois
    - <https://external-secrets.io/latest/>
    - <https://developer.hashicorp.com/vault/docs/deploy/kubernetes/vso>
    - <https://bank-vaults.dev/docs/mutating-webhook/>
  - Déployer les sous instances ArgoCD sur chaque cluster via l'ArgoCD principal :white_check_mark:
- Sujet
  - [Anubis](https://anubis.techaro.lol/)
  - [Argocd V3](https://github.com/argoproj/argo-cd/releases/tag/v3.0.0)
- Bilan
  - Déploiement d'ArgoCD en V3.0.0 sur Main Cluster
  - Déploiement d'Authentik sur Main Cluster
  - Beaucoup de documentation lue et validation de la configuration d'ArgoCD

### Stream 3 mai 2025

- Debut : 16h30
- FIN : ~ 19H40 - [Stream 3H18]
- Vod : [Twitch](https://www.twitch.tv/videos/2449245677) [YouTube](https://youtu.be/zbPGIamezNI)
- Musique: [NCS](https://ncs.io/)
  - [NCS: The Best of 2025 ⚡️](https://www.youtube.com/playlist?list=PLRBp0Fe2GpgkDw2aMG2lM5heA8cbLvOoN)
- Objectif (Pas dans l'ordre):
  - Passage a Talos V1.10.0 progressif, créer un cluster en v1.9 puis le migrer vers v1.10.0, vérifier que tout fonctionne et ensuite faire la mise a jour de l'image de base/template
    - [Talos Upgrade](https://www.talos.dev/v1.10/talos-guides/upgrading-talos/)
    - [Kubernetes Upgrade](https://www.talos.dev/v1.10/kubernetes-guides/upgrading-kubernetes/)
    - [Cluster API Upgrade](https://github.com/batleforc/weebo-si/pull/100)
- Sujet
  - [Talos v1.10.0](https://github.com/siderolabs/talos/releases/tag/v1.10.0)
- Bilan
  - Upgrade de Talos v1.10.0 fait sur le cluster Main et passage en kubernetes v1.33.0
  - Automatisation de l'upgrade de Talos et Kubernetes effectué

### Stream 26 avril 2025 - Pause (Out Of Town)

### [Stream 19 avril 2025](/0.introduction/stream/19-04-2025.html)

### [Stream 12 avril 2025](/0.introduction/stream/12-04-2025.html)

### Stream 5 avril 2025 - Pause (Out Of Town)

### [Stream 29 mars 2025](/0.introduction/stream/29-03-2025.html)

### [Stream 22 mars 2025](/0.introduction/stream/22-03-2025.html)

### [Stream 15 mars 2025](/0.introduction/stream/15-03-2025.html)

## Music

- [Chillhop](https://app.chillhop.com/)<= Plus calme
- [NCS](https://ncs.io/) <= Plus rythmé et varié (Pas encore testé)

## Task

### us9 - Mettre en place updatecli

- [x] Créer un fichier de configuration updatecli
- [x] Mise en place CI/CD
- [x] Automatiser la mise a jour des outils dans le script ansible
- [x] Automatiser la mise a jour des outils dans l'image Che-Ops
- [x] Automatiser la mise a jour des Traefik
- [x] Automatiser la mise a jour des CertManager
- [x] Automatiser la mise a jour des Cilium
- [x] Automatiser la mise a jour des Talos
- [ ] Automatiser la mise a jour des ArgoCD

### us15 - Faire une gestion DNS avec alias dynamique ✅

Solution possible ?

- [CoreDNS](https://coredns.io/) - Need ETCD ❌
- [RFC2136](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/tutorials/rfc2136.md) - Need Bind9 ✔️

Mise en place d'un serveur DNS avec Bind9 et une automatisation via l'opérateur [External DNS](https://github.com/kubernetes-sigs/external-dns). En plus de l'opérateur External DNS, passage par les [CRD](https://github.com/kubernetes-sigs/external-dns/blob/master/docs/sources/crd.md) comme source.

- 1 Zone DNS weebo.
  - *.capi.weebo.poc => CAPI
  - *.main.weebo.poc => Main-Cluster
  - *.dev.weebo.poc => Dev-Cluster
  - *.test.weebo.poc => Test-Cluster
  - *.prod.weebo.poc => Prod-Cluster
- Record A / AAAA / NS / CNAME / TXT
- Forwarding du reste des requêtes en fonction de mon envie a l'instant T
  - <https://www.baeldung.com/linux/bind9-dns-server-configuration>

### us16 - Autorité de certification

Mise en place d'une autorité de Certification RootCA / IntermediateCA via [Bank Vaults](https://bank-vaults.dev/) et de son orchestrations.

Ne pas oublier une migration vers OpenBao quand celui-ci sera supporté par le projet.

- [Tuto HashiCorp](https://developer.hashicorp.com/vault/tutorials/pki/pki-engine)
- [Tuto OpenBao](https://openbao.org/docs/secrets/pki/quick-start-root-ca/)
- [A suivre](https://github.com/bank-vaults/bank-vaults/issues/3077)
- [Exemple](https://github.com/bank-vaults/bank-vaults/blob/main/vault-config.yml)
- [Google trust ?](https://serverfault.com/questions/946756/ssl-certificate-in-system-store-not-trusted-by-chrome) - Maybe ?

L'objectif est que chaque Cluster puisse avoir son propre IntermediateCA et que l'autorité RootCA soit présente sur CAPI dans la déclinaison Vault présente.

Via la RFC2136, il sera possible de faire du DNS01 et a défaut du HTTP01 pour la création des certificats et sans oublier via [CertManager](https://cert-manager.io/docs/) pour la gestion des certificats.

Chaque cluster aura son propre sous-groupe de KV partageable.
