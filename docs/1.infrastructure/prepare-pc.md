# Préparation du poste de travail

Afin de préparer votre poste le plus efficacement possible, des script automatisés sont disponibles. Ces scripts sont écrits sois via un Taskfile, sois via un Playbook Ansible.

::: info

Toute les commande sont à exécuter à la racine du projet.

:::

## 0. Pré-requis

Afin de pouvoir exécuter ces script vous aurez tout de même besoin de quelques outils :

- [Cocogitto](https://github.com/cocogitto/cocogitto)
- [Python](https://www.python.org/downloads/)
- [Kubectl](https://kubernetes.io/fr/docs/tasks/tools/install-kubectl/)
- [Helm](https://helm.sh/docs/intro/install/)
- [Taskfile](https://taskfile.dev/#/installation)
- [A good text editor](https://code.visualstudio.com/)
- [Git](https://git-scm.com/downloads)
- [Un ide Graphique](https://www.vscode.com)
- [Ou un ide Terminal](https://helix-editor.com/)
- Et surtout, un terminal

## 1. Initialisation du venv python

```bash
task init:init-venv
```

Ce script va tenté d'installer python3-pip et python3-venv via apt puis créer un environnement virtuel python3 dans le dossier `.venv`.

## 2. Installation des dépendances Ansible

```bash
task init:install-ansible
```

Ce script va installer Ansible et toutes les dépendances nécessaires à son bon fonctionnement. Celle ci sont présente dans le fichier requirements.txt du dossier 0.ansible.

## 3. Installation des dépendances du projet

```bash
task init:install-cli
```

Ce script va installer toutes les ligne de commande nécessaire au bon fonctionnement du projet. Cela inclus lors de la rédaction de cette page:

- argocd
- clusterctl
- gitleaks
- k9s
- talosctl
- terraform

## 4. Installation des hooks git

```bash
task init:install-hook
```

Ce script va installer les hooks git définis dans le fichier cog.toml. Ces hooks sont utilisés pour s'assurer que :

- L'inventaire ansible est bien chiffrer avant d'être commité.
- Aucun secret n'est présent dans les fichiers de configuration.
- Le format du message de commit est correct.

Ces hooks pourront être étendu au fur et à mesure des besoins.
