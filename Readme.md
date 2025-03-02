# Weebo SI

Ce projet est double et séparer en deux:

- un poc pour la mise en place de Talos sur un cluster Proxmox via la CAPI, celui ci est basé sur le [super article](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) de [Une tasse de café](https://une-tasse-de.cafe/) (que je meurt d'envie d'essayer depuis qu'il est sortit).
- La redéfinitions de l'env Weebo (ou dans mes rêves, l'Env presque parfait).

Avant toute chose, il est important de noter que ce projet est un projet personnel et que je ne suis pas un expert dans toutes les technologies utilisées. Ce projet est un moyen pour moi de continuer a apprendre mais surtout de m'amuser en définissant mon Env parfait. Je vous prierais par contre de me cité si vous utilisez ce projet pour vos propres besoins.

## Technologies utilisées

- [Taskfile](https://taskfile.dev/#/)
- [Ansible](https://www.ansible.com/)
- [Terraform](https://www.terraform.io/)
- [Talos](https://www.talos.dev/)
- [Proxmox](https://www.proxmox.com/)
- [CAPI](https://cluster-api.sigs.k8s.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)

## Objectifs

### 1. Création de l'infrastructure

Mes connaissances en Talos/Proxmox/CAPI sont nulls, donc on est sur du Zero to Hero (ou du moins j'espère).

- [ ] Sur un noeud Proxmox, installer un Mono-Node Talos via la CAPI
- [ ] Sur un noeud Proxmox, installer un Multi-Node Talos via la CAPI
- [ ] Tester [KubeVirt](https://kubevirt.io/)

### 2. Gestion de l'infrastructure

Bon on a nos clusters, maintenant il faut les gérer. Pour cela, on va utiliser mon outil préféré, ArgoCD.

- [ ] Créer un déploiement ArgoCD pour la gestion de l'infrastructure (Master Cluster et Worker Cluster)
- [ ] Créer un déploiement ArgoCD pour la gestion des applications (Ingress, Monitoring, Logging, etc.)
- [ ] Mettre en place une interface pour mutualisé le monitoring des clusters

### 3. Déployer des applications

La création de l'infrastructure et sa gestion c'est bien, mais il faut aussi mettre en place le coeur de l'env Weebo.

- [ ] Déployer un Ingress Controller
- [ ] Déployer Cert-Manager
- [ ] Déployer un Monitoring Stack
- [ ] Déployer un Logging Stack
- [ ] Déployer un CI/CD (Tekton)
- [ ] Déployer un Registry (Ou utiliser mon registre privé)
- [ ] Déployer Vault x Bank-Vaults x External-Secrets
- [ ] Déployer l'environnement de dev "Parfait"
- [ ] Déployer un CNI ([Cilium](https://cilium.io/)) et un Observateur ([Falco](https://falco.org/), [Tetragon](https://tetragon.io/))

### 4. Environnement de dev "Parfait"

L'env de base est en place, maintenant il faut ajouter tout les outils pour s'approcher de l'env de dev parfait.

- [ ] Ide cloud native ([Eclipse Che](https://www.eclipse.org/che/))
- [ ] Repository ([Gitea](https://gitea.io/))
- [ ] CI/CD ([Tekton](https://tekton.dev/))
- [ ] Registry ([Harbor](https://goharbor.io/))
- [ ] Monitoring ([Prometheus](https://prometheus.io/), [Grafana](https://grafana.com/))
- [ ] Logging ([Loki](https://grafana.com/loki/), [Grafana](https://grafana.com/))
- [ ] Vault ([Vault](https://www.vaultproject.io/), [Bank-Vaults](https://banzaicloud.com/products/bank-vaults/))
- [ ] Dashboard de dev ([Backstage](https://backstage.io/))
- [ ] Déploiement d'application ([ArgoCD](https://argoproj.github.io/argo-cd/), [Argo Rollouts](https://argoproj.github.io/argo-rollouts/))
- [ ] Prévenir et détecter les vulnérabilités ([Trivy](https://trivy.dev/latest/), [Popeye](https://popeyecli.io/), [Dependency-Track](https://dependencytrack.org/))
- [ ] Sécuriser les accès ([Oathkeeper](https://www.ory.sh/oathkeeper/), [Keto](https://www.ory.sh/keto/), [Oauth2-Proxy](https://oauth2-proxy.github.io/oauth2-proxy/), [Zitadel](https://zitadel.com/))
- [ ] Sécuriser le réseau ([Cilium](https://cilium.io/), [Falco](https://falco.org/), [Tetragon](https://tetragon.io/))
- [ ] Sécuriser les déploiements ([Opa](https://www.openpolicyagent.org/), [Gatekeeper](https://www.openpolicyagent.org/docs/latest/kubernetes-introduction/), [Kyverno](https://kyverno.io/))

### 5. User friendly

Bon, on a tout ce qu'il faut pour développer, mais il manque des outils pour faciliter la vie de tout les jours.

- [ ] Installer une partit ChatOps ([Mattermost](https://mattermost.com/), [Rocket.Chat](https://rocket.chat/), [Matrix](https://matrix.org/))
- [ ] Installer une partit Wiki ([Docusaurus](https://docusaurus.io/))
- [ ] Faciliter les automatismes ([N8N](https://n8n.io/), [Node-Red](https://nodered.org/))

### 6. Intégration

Plein de services sont en place, mais ils ne sont pas systématiquement intégrés entre eux. C'est toujours mieux un Dashboard qui regroupe tout.

- [ ] Intégrer tout les services entre eux

### 7. Aller plus loin

Tout est en place, mais il manque encore des choses pour être parfait. Et pourquoi pas tout casser pour voir si ça tient la route.

- [ ] Chaos Engineering ([Chaos Mesh](https://chaos-mesh.org/), [Litmus](https://litmuschaos.io/))

## Participating

Please, before contributing, read the [CONTRIBUTING.md](CONTRIBUTING.md) file.

## Sources

- [Une tasse de café - CAPI/Proxmox](https://une-tasse-de.cafe/blog/talos-capi-proxmox/)
- [Use tasse de café - Talos](https://une-tasse-de.cafe/blog/talos/)
- [AbyssProject](https://wiki.abyssproject.net/en/proxmox/proxmox-with-one-public-ip)
- [Stéphane Robert - Ansible](https://blog.stephane-robert.info/docs/infra-as-code/gestion-de-configuration/ansible/introduction/)
- [Stéphane Robert - Ansible X Proxmox](https://blog.stephane-robert.info/docs/virtualiser/type1/proxmox/ansible-modules/)
- [Stéphane Robert - Terraform X Proxmox](https://blog.stephane-robert.info/docs/virtualiser/type1/proxmox/terraform/)
