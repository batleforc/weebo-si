# Création du cluster Mono Noeud CAPI

Dans cette partie, nous allons créer un premier cluster mono-noeud Kubernetes avec Talos. Ce cluster sera composé d'un seul noeud Master sur lequel les workloads seront déployés.

La volonté originelle de ce cluster étais de reproduire l'article [Une tasse de café - CAPI/Proxmox](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) mais de le rendre complètement automatisé avec Terraform. Celui ci ma permis de mieux comprendre le fonctionnement des templates Talos et le fonctionnement du provider Proxmox pour Terraform. La création de cluster via la cluster api est un sujet abordé dans une autre partie.

A la suite de la création de ce cluster, l'objectif est d'automatiser la création de clusters mono/multi-noeud avec Talos et d'installer les briques de base pour manipuler ces clusters. Ce faisant, nous arrivons a du cluster as a service avec Talos.

## Objectifs

- Créer un cluster mono-noeud Kubernetes Talos avec Terraform X Proxmox
- Installer les outils de base pour manipuler le cluster

## Let's do it

### Prérequis

- Avoir suivis :
  - [Préparation du poste de travail](/0.setup/prepare-pc)
  - [Préparation du serveur](/1.Proxmox/1.infrastructure/prepare-server)
  - [Préparation pour nos première VM](./prepare-first-vm.md)
- Avoir créé un PAT Github en lecture seule sur le repository privé et l'avoir stocké dans le fichier `.env` à la racine du projet.

### 1. Création du cluster

```bash
task capi:init
```

### 2. Installation des outils de base

```bash
task capi:argo:install
task capi:argo:port-forward
```

Puis dans un autre terminal en parallèle :

```bash
task capi:argo:login-pf
task capi:argo:init-private-repo
task capi:argo:install-app
```

### Résultat

Oui, une commande pour tous les gouverner. Vous aurez un cluster mono-noeud Kubernetes Talos prêt a l'emploi. et avec les 5 autres commandes, vous aurez les outils de base pour manipuler ce cluster. Magique non ? 🪄

## Kesako ?

Rien n'est vraiment magique, tout est automatisé. Pour cela, nous avons utilisé Terraform pour créer le cluster et ArgoCD pour installer les outils de base. Voici comment cela fonctionne :

### Terraform again ?

Et bien oui, Terraform c'est occuper a partir de ce qui est fait dans l'étape de préparations de créer un simple cluster mono-noeud Kubernetes Talos basé sur notre template "Metal".

Pour ce faire, l'installation du cluster est découpé en 2 étapes :

- Création de la VM Talos basé sur le template "Metal".
- Bootstrap du cluster Kubernetes pour insuffler la configuration Talos souhaité.

Cette ordonnancement est presque implicite dans le code Terraform vue que pour Bootstrap Talos, il est nécessaire de connaître l'ip de la VM. Pour cela, une variable "local" est utilisé pour trouver l'ip de la VM et la passer au module de bootstrap.

```hcl
locals {
  capi_possible_ip = [for ip in [for ip in proxmox_virtual_environment_vm.capi_template.ipv4_addresses : ip if length(ip) > 0] : ip if ip != tolist(["127.0.0.1"]) && ip != ["127.0.0.1"] && startswith(ip[0], "192.168.")]
}

output "capi_ip" {
  value = element(local.capi_possible_ip[0], 0)
}
```

Cette variable filtre les ip récupérer par proxmox via le `qemu-guest-agent` pour ne garder que les ip qui nous intéresse (pas de loopback ni d'ip privé). Sans oublier de l'afficher a l'écran pour que l'utilisateur puisse la récupérer sans a avoir a accéder a l'interface proxmox.

Par sécurité une dépendance `depends_on` est ajouté pour que le bootstrap soit bien exécuté après la création de la VM.

```hcl
resource "talos_machine_secrets" "capi_secret" {
  depends_on = [resource.proxmox_virtual_environment_vm.capi_template]
}
```

### Talos Bootstrap

Maintenant que la VM est créé et que le bootstrap ne peut être exécuté uniquement après la création de la VM, il est temps de passer a l'installation du cluster Kubernetes.

La préparation du Bootstrap est découpé en 3 étapes :

- Création des secrets du cluster.
- Création de la configuration machine pour le control plane en n'oubliant pas de lui précisé qu'il fait aussi office de worker.
- Création de la configuration client en injectant l'ip de la VM.

Ces trois étape effectué, un apply de la configuration pour le noeud control plane est effectué. Cela va déclencher le bootstrap du cluster Kubernetes.

Une fois le bootstrap terminé, terraform va créer les fichiers Kubeconfig et talosconfig pour que l'utilisateur puisse se connecter au cluster.

### ArgoCD

ArgoCD est un outils du paradigme GitOps qui va nous permettre de déployer et résoudre l'état désiré au sein de notre cluster Kubernetes. Pour cela, ArgoCD va surveiller un repository Git et appliquer les changements sur le cluster Kubernetes.

Son installation `task capi:argo:install` ce fait a l'aide d'un Helm Chart. Une fois installé, il est nécessaire de le configurer pour qu'il puisse accéder au repository Git. Pour cela, un port-forward est effectué pour accéder a l'interface web d'ArgoCD.

Le port-forward effectué nous permet aussi de finaliser la configuration en lui injectant les informations de connexion au repository Git et une application ArgoCD utilisant le repository.
