# Architecture des noeud et répartition des services

```mermaid
architecture-beta
    group lab(mdi:cloud)[Weebo_lab]

    service proxmox(mdi:cloud)[Proxmox] in lab
    service weebo4(mdi:server)[Weebo4] in lab
    service weeboX(mdi:server)[WeeboX] in lab
    service weebo4_local(mdi:harddisk)[Weebo4_Local] in lab

    service dhcp(mdi:router-network)[Dhcp_vmbr1] in lab

    service pc(mdi:desktop-classic)[PC]

    weebo4:T -- B:proxmox
    weeboX:T -- B:proxmox
    weebo4_local:R -- L:weebo4
    proxmox:L -- R:dhcp

    pc:L -- R:proxmox
```

Dans cette architecture, on dois pouvoir avoir plusieurs noeud Proxmox. Notre base est le noeud Weebo4 mais nos applicatif pourrons et devrons être réparti sur plusieurs noeud. Pour le représenté, on ajouter le noeud WeeboX.

Chaque actions sur l'environnement devra être reproductible et automatisé. Pour cela, on utilise la logique GitOps et des jobs/CronJobs pour automatiser les taches via du Terraform ou de l'Ansible.

## Cluster CAPI - Single Point Of Failure

Le cluster CAPI est le cluster qui va gérer les autres clusters. Il est pour le moment en mono-node mais devrais passer en multi-node avec l'ajout d'un noeud Proxmox.

Celui-ci est voué a gérer les autres clusters. Et ce via l'API de Kubernetes.

Les seules applications qui tournerons sur ce cluster sont:

- [ArgoCD](https://argoproj.github.io/argo-cd/)
- [Traefik](https://doc.traefik.io/traefik/) => Reverse Proxy pour HeadLamp et ArgoCD
- [Cert-Manager](https://cert-manager.io/docs/) => Gestion des certificats
- [Headlamp](https://headlamp.dev/) => Interface de gestion de Kubernetes

```mermaid
flowchart TD
  subgraph "Proxmox - Weebo4"
    subgraph "CAPI"
      traefik["Traefik"]
      cert-manager["Cert-Manager"]
      headlamp["Headlamp"]
      argo@{ icon: "logos:argo", pos: "t", h: 60 }
      capi["Cluster api"]
    end
    MonoNode@{ icon: "mdi:kubernetes", label: "Mono Node", pos: "t", h: 60 }
    MultiNode@{ icon: "mdi:kubernetes", label: "Multi Node", pos: "t", h: 60 }
    MultiNodeX@{ icon: "mdi:kubernetes", label: "Multi Node X", pos: "t", h: 60 }
  end

  argo -- Ask creation of cluster --> capi
  capi -- Create cluster --> MonoNode
  argo -- Orchestrate --> MonoNode
  capi -- Create Cluster --> MultiNode
  argo -- Orchestrate --> MultiNode
  capi -- Create Cluster --> MultiNodeX
  argo -- Orchestrate --> MultiNodeX
```

## Les clusters enfants

Chaque cluster enfant de la CAPI devra être provisionné par le cluster CAPI et porté une authentification OIDC. Cette authentification sera géré par Zitadel et disponible une fois que le premier cluster sera provisionné. (Nécessite un double déploiement du premier cluster)

En plus de l'authentification, chaque cluster enfant devra avoir les applications suivantes:

- [Traefik](https://doc.traefik.io/traefik/) => Reverse Proxy pour les applications
- [Cert-Manager](https://cert-manager.io/docs/) => Gestion des certificats
- [Prometheus Stack](https://prometheus.io/docs/introduction/overview/) => Monitoring des applications
  - Prometheus pour la collecte des métriques et l'envoie vers le serveur central
  - Promtail pour la collecte des logs et l'envoie vers le serveur Loki central
  - Otel Operator pour la collecte des traces et l'envoie vers le serveur Tempo central
- [Falco](https://falco.org/docs/) => Détection d'anomalie qui seront envoyé a Talon mais aussi a un Tempo centralisé
- [Talon](https://github.com/falcosecurity/falco-talon) => Réponse aux anomalies
- Une solution de backup pour les parties nécessaires ou les données seront envoyé vers un bucket S3

```mermaid
flowchart TD
  subgraph "Proxmox - Weebo4"
    subgraph "Weebo 4"
      subgraph "CAPI"
        traefik["Traefik"]
        cert-manager["Cert-Manager"]
        headlamp["Headlamp"]
        argo@{ icon: "logos:argo", pos: "t", h: 60, label: "ArgoCD - Maitre" }
        capi["Cluster api"]
      end
    end
    subgraph "Weebo X"
      subgraph "Cluster 1 - Main"
        MultiNode@{ icon: "mdi:kubernetes", label: "Multi Node", pos: "t", h: 60 }
        argo1@{ icon: "logos:argo", pos: "t", h: 60, label: "ArgoCD - Client" }
        traefik1["Traefik"]
        cert-manager1["Cert-Manager"]
        prom-stack1["Monitoring Central"]
        falco1["Falco"]
        talon1["Talon"]
        zitadel1["Zitadel"]
        other-apps1["Other Apps"]
      end
    end
    subgraph "Weebo X"
      subgraph "Cluster X - Child"
        MultiNodeX@{ icon: "mdi:kubernetes", label: "Multi Node X", pos: "t", h: 60 }
        argoX@{ icon: "logos:argo", pos: "t", h: 60, label: "ArgoCD - Client" }
        traefikX["Traefik"]
        cert-managerX["Cert-Manager"]
        prom-stackX["Prometheus Stack"]
        falcoX["Falco"]
        talonX["Talon"]
        other-appsX["Other Apps"]
      end
    end
  end
```

## Main Multi-Node Talos

Ce cluster principal va porter la charge de travail centrale. Il est le cluster principal pour les applications mais n'est pas dédié a des applications dites "sensibles". Il est le cluster principal pour les application centrales.

```mermaid
flowchart RL
  subgraph "Proxmox"
    subgraph "Multi-Node Talos"
      argo["Argo Client"]@{ icon: "logos:argo", pos: "t", h: 60 }
      truc["Stack Central"]
      zitadel["Zitadel"]
      tekton["Tekton"]
      other-apps["Other Central Apps"]
    end
  end

  argo -- Deploy --> truc
  argo -- Deploy --> zitadel
  argo -- Deploy --> tekton
  argo -- Deploy --> other-apps
```

## Child Multi-Node Talos

Ces clusters sont les clusters enfants du cluster principal. Ils sont dédié a des applications sensibles ou métier et ne sont pas accessible directement depuis l'extérieur. Ils sont accessible via le cluster principal ou via un VPN.

```mermaid
flowchart LR
  subgraph "Proxmox"
    subgraph "Multi-Node Talos"
      argo["Argo Client"]@{ icon: "logos:argo", pos: "t", h: 60 }
      truc["Stack dédié"]
      other-apps["Sensibles Apps"]
    end
  end

  argo -- Deploy --> truc
  argo -- Deploy --> other-apps
```
