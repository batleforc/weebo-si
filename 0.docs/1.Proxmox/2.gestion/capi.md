# Mise en place CAPI

Il est temps d'attaquer la partie Cluster As A Service ! Maintenant que le cluster Maitre CAPI est créé, il est temps d'installer l'opérateur Cluster API qui permettra à l'avenir d'instancier les clusters enfant et de les manager via une logique GitOps !

## Installation de l'opérateur CAPI

### Prérequis

- Un cluster Kubernetes v1.20 ou supérieur
- ArgoCD ou un autre outil de GitOps
- Cert-manager

### Préparation pour la connexion à Proxmox

Avant de pouvoir créer les différents clusters, il est nécessaire de fournir à l'opérateur CAPI les informations de connexion à Proxmox. Pour cela, il faut créer un secret contenant les informations d'authentification.

- PROXMOX_URL : URL de l'API Proxmox
- PROXMOX_USERNAME : Nom d'utilisateur Proxmox
- PROXMOX_PASSWORD : Mot de passe Proxmox

Si vous avez valorisé votre fichier .env a la suite des étapes de préparation, il vous suffit de faire la commande suivante :

```bash
task capi:init-provider
```

Cette commande va exécuter le script Terraform présent dans le dossier `capi.terraform_init` et va créer le secret `infra-provider` dans le namespace `cluster-api`.

### Installation de l'opérateur

L'installation de l'opérateur ce fait via une Application Helm.

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cluster-operator
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  syncPolicy:
    automated: {}
  source:
    chart: cluster-api-operator
    repoURL: https://kubernetes-sigs.github.io/cluster-api-operator
    targetRevision: 0.19.0 # Version de l'opérateur
    helm:
      releaseName: cluster-operator
      valuesObject:
        core:
          cluster-api:
            version: v1.10.1 # Version du contrôleur CAPI
        infrastructure:
          proxmox:
            version: v0.7.0 # Version du contrôleur Infrastructure Proxmox, déclinaison par Ionos
        controlPlane:
          talos:
            version: v0.5.10 # Version du contrôleur de control plane Talos
        bootstrap:
          talos:
            version: v0.6.9 # Version du contrôleur de bootstrap Talos (Bootstrap autant les machine worker que control plane)
        ipam:
          in-cluster:
            version: v1.0.1 # Version du contrôleur d'IPAM
        addon:
          helm:
            version: v0.3.1 # Version du contrôleur d'addon Helm
        configSecret: # Emplacement du secret créer précédemment
          name: "infra-provider"
          namespace: "cluster-api"
        cert-manager:
          enabled: true # Indique que les opérateurs peuvent utiliser cert-manager pour créer des certificats
  destination:
    server: "https://kubernetes.default.svc"
    namespace: cluster-api-operator-system
```

Cette opérateur va installer les contrôleurs suivants :

- Cluster API
- Proxmox - Infrastructure, déclinaison par Ionos créant les machines virtuelles
- Talos - Control Plane et Bootstrap, gérant l'orchestration du control plane et le bootstrap des machines
- IPAM - In-cluster, gérant l'attribution des IPs
- Helm - Addon, gérant l'installation de charts Helm

Et l'installation de l'opérateur est terminée ! Vous pouvez vérifier que l'opérateur est bien installé via l'interface ArgoCD `192.168.100.11/argocd`.
