# Weebo SI

Ce projet a pour but de définir et de mettre en place un environnement Kubernetes de développement et d'expérimentation, testé et complet. Cet environnement est `presque` parfait car les choix d'aujourd'hui ne seront pas forcément ceux de demain.

Le but initial de ce projet était :

- un POC pour la mise en place de Talos sur un cluster Proxmox via la CAPI, celui-ci est basé sur le [super article](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) de [Une tasse de café](https://une-tasse-de.cafe/) (que je mourais d'envie de tester).
- La définition puis redéfinition de l'environnement dit presque parfait.

Avant toute chose, il est important de noter que ce projet est un projet personnel et que je ne suis pas un expert dans toutes les technologies utilisées. Ce projet est un moyen pour moi de continuer à apprendre mais surtout de m'amuser en définissant mon environnement parfait. Je vous prierais par contre de me citer si vous utilisez ce projet pour vos propres besoins.

## Technologies utilisées

- [Taskfile](https://taskfile.dev/#/)
- [Ansible](https://www.ansible.com/)
- [Terraform](https://www.terraform.io/)
- [Talos](https://www.talos.dev/)
- [Proxmox](https://www.proxmox.com/)
- [CAPI](https://cluster-api.sigs.k8s.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)

## Organisation du projet

Le projet est organisé de la manière suivante :

- `.github` : Contient les actions GitHub comme le déploiement de la documentation.
- `.vscode` : Contient la configuration de Visual Studio Code (extensions, paramètres, ...).
- `.venv` : Contient l'environnement virtuel Python. Ce dossier n'est pas versionné et donc présent dans le gitignore.
- `0.docs` : Contient la documentation du projet.
- `0.*` : Contient les étapes initiales du projet.
  - `0.ansible` : Contient les playbooks Ansible.
  - `0.terraform` : Contient les scripts Terraform.
  - `0.task` : Contient les tâches Taskfile pour automatiser les étapes initiales du projet.
  - `0.pulumi` : Contient les scripts Pulumi, plus précisément ceux destinés à bootstrapper un cluster Talos sur OVH depuis zéro.
- `1.proxmox` : Emplacement où retrouver le résultat de la première version basée sur Proxmox.
  - `capi.*` : Contient le nécessaire pour créer/manager le cluster CAPI.
    - `capi.argo` : Contient les fichiers ArgoCD pour le cluster CAPI afin d'implémenter la logique GitOps.
    - `capi.task` : Contient les tâches Taskfile pour automatiser les étapes de gestion du cluster CAPI.
    - `capi.terraform` : Contient les scripts Terraform pour la création/maintien en état nominal du cluster CAPI (création VM, bootstrap Talos, etc).
    - `capi.terraform_init` : Contient les scripts Terraform pour bootstrapper la cluster API et lui permettre l'accès au cluster Proxmox.
- `$OLD_CLUSTER_NAME.*` : Contiendra les informations nécessaires pour manager le cluster $OLD_CLUSTER_NAME.
- `$CLUSTER_NAME.*` : Contiendra les informations nécessaires pour manager le cluster $CLUSTER_NAME. Nouvelle approche pour la seconde version ALL-IN-ONE.
  - `$CLUSTER_NAME.argo` : Stockage des différents manifests
    - `app` : Manifeste initial, point d'entrée ArgoCD
    - `helm` : Regroupement des différents Helm Charts
    - `terra` : Regroupement de l'approche GitOps x Terraform permettant de configurer certaines applications à la volée
  - `$CLUSTER_NAME.task` : Regroupement des différents Taskfile propres à un projet
- `all-in-one.*` : Deuxième version basée sur KubeVirt
