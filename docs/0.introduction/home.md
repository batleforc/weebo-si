# Weebo SI

Ce projet a pour but de définir et de mettre en place un environnement Kubernetes de dev et expérimentation tester et complet. Cette environnement est `presque` parfait car les choix d'aujourd'hui ne seront pas forcément ceux de demain.

Le but initial de ce projet étais :

- un poc pour la mise en place de Talos sur un cluster Proxmox via la CAPI, celui ci est basé sur le [super article](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) de [Une tasse de café](https://une-tasse-de.cafe/) (que je mourait d'envie de tester).
- La définitions puis redéfinitions de l'env dis presque parfait.

Avant toute chose, il est important de noter que ce projet est un projet personnel et que je ne suis pas un expert dans toutes les technologies utilisées. Ce projet est un moyen pour moi de continuer a apprendre mais surtout de m'amuser en définissant mon Env parfait. Je vous prierais par contre de me cité si vous utilisez ce projet pour vos propres besoins.

## Objectifs

Achat du serveur Lab le 1 mars 2024 => Objectif du MVP 1 autour de la premiere semaine d'avril 2024.

## Technologies utilisées

- [Taskfile](https://taskfile.dev/#/)
- [Ansible](https://www.ansible.com/)
- [Terraform](https://www.terraform.io/)
- [Talos](https://www.talos.dev/)
- [Proxmox](https://www.proxmox.com/)
- [CAPI](https://cluster-api.sigs.k8s.io/)
- [ArgoCD](https://argoproj.github.io/argo-cd/)

## Organisation du projet

Le projet est organisé de la manière suivante:

- `.github` : Contient les actions GitHub comme le déploiement de la doc.
- `.vscode` : Contient la configuration de Visual Studio Code. (Extensions, settings, ...)
- `.venv` : Contient l'environnement virtuel Python. Ce dossier n'est pas versionné et donc dans le gitignore.
- `docs` : Contient la documentation du projet.
- `0.*` : Contient les étapes initial du projet.
  - `0.ansible` : Contient les playbooks Ansible.
  - `0.terraform` : Contient les scripts Terraform.
  - `0.task` : Contient les tâches Taskfile pour automatiser les étapes initial du projet.
- `capi.*` : Contient le nécessaire pour Créer/Manager le cluster CAPI.
  - `capi.argo` : Contient les fichiers ArgoCD pour le cluster CAPI afin d'implémenter la logique GitOps.
  - `capi.task` : Contient les tâches Taskfile pour automatiser les étapes de gestion du cluster CAPI.
  - `capi.terraform` : Contient les scripts Terraform pour la création/maintient en état nominale du cluster CAPI (Création VM, Bootstrap Talos, etc).
  - `capi.terraform_init` : Contient les scripts Terraform pour Bootstrap la cluster API et lui permettre l'accès au cluster Proxmox.
- `$CLUSTER_NAME.*` : Contiendra les information nécessaire pour Manager le cluster $CLUSTER_NAME.
