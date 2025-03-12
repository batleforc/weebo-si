# Weebo SI

Ce projet est double et séparer en deux:

- un poc pour la mise en place de Talos sur un cluster Proxmox via la CAPI, celui ci est basé sur le [super article](https://une-tasse-de.cafe/blog/talos-capi-proxmox/) de [Une tasse de café](https://une-tasse-de.cafe/) (que je meurt d'envie d'essayer depuis qu'il est sortit).
- La redéfinitions de l'env Weebo (ou dans mes rêves, l'Env presque parfait).

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