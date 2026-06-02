# Préparation du serveur cible

Afin de préparer votre serveur le plus efficacement possible, des prérequis sont nécessaires.

Si ces prérequis sont respectés, vous pourrez alors exécuter des scripts automatisés. Ces scripts sont écrits via un Taskfile.

Pour plus de facilité, un vpn va être installé sur le serveur. Cela permettra d'interagir directement avec les différents services installés.

::: info

Toute les commande sont à exécuter à la racine du projet.

:::

## 0. Pré-requis

Votre serveur doit comporter les éléments suivants :

- [Proxmox déjà installer](https://www.proxmox.com)
- Plus de 8Go de RAM
- Plus de 2 coeur
- Plus de 100Go de disque
- Une connexion internet
- Un accès SSH avec une clef SSH pré installer
- Un accès à l'interface web de Proxmox

## 1. Setup SSH Initial et Hardening

Avant de commencer, il est nécessaire d'appliquer quelques configuration de sécurité initiale sur le serveur:

- Changer le port SSH par défaut (22) pour le port 2323
- Désactiver l'accès SSH par mot de passe
- Forcer le SSH à utiliser la version 2
- Passage du temps pour ce connecter en 20 secondes par connection
- Nombre de tentative de connexion SSH par connection a 3
- Limiter le nombre de connexion SSH vivante a 3
- Limiter l'interval entre deux tentatives de connexion SSH a 120 secondes
- Désactiver la bannière de status SSH
- Désactiver les protocole de connection non supporté (GSSAPI, KERBEROS)
- Désactiver le X11 forwarding
- Mise en place Fail2Ban

Tout ceci afin d'appliquer un hardening minimale de sécurité en accord avec le [SSH Hardening Guide](https://ittavern.com/ssh-server-hardening/).

Pour cela, exécuter la commande suivante :

```bash
task proxmox:change-ssh-port
```

## 2. Initialisation de la configuration VPN

Le vpn utilisé dans notre cas est [WireGuard](https://www.wireguard.com/). Pour l'installer, vous pouvez suivre le tutoriel suivant : [WireGuard - Installation](https://www.wireguard.com/install/).

La gestion de la configuration ce fait a travers Terraform. Dans le dossier `0.terraform/vpn-proxmox`, vous trouverez tout les fichier de configuration nécessaire, ainsi que:

- `main.tf` : Main terraform qui permet la définition des providers ainsi que les variables
- `server.tf` : Définition de la configuration du serveur, attribution des plage IP et des scripts de démarrage/extinction de wireguard. Cette configuration est écrite dans le fichier `server.wg.conf`.
- `pc1.tf` : Définition de la configuration du client, attribution d'une ip unique et déclaration des plages ip devant passer par le vpn. Cette configuration est écrite dans le fichier `pc1.wg.conf`.

Pour lancer la configuration, resté a la racine du projet git et exécuté la commande suivante :

```bash
task proxmox:init-vpn-config
```

::: warning

La configuration de wireguard `pc1.wg.conf` utilise deux serveur DNS, le noeud CAPI qui portera le serveur DNS centralisé et le dns google 8.8.8.8

:::

## 3. Configuration du serveur

Ce script a différentes étapes :

- Mettre a jour le système
- Installer les paquets nécessaires (Curl, Git, Vim, ufw, DNSMasq)
- Mise en place du Firewall UFW et création de la carte VMBR1 ainsi que du serveur DHCP
- Installer WireGuard
- Configurer WireGuard en lui téléversant le fichier de configuration générés précédemment et démarrage de wireguard en mode service.
- Création d'un utilisateur `weebo-env@pve` avec un token d'authentification qui serra utilisé par terraform lors des prochain script.
- Définition de la zone Timezone sur `Europe/Paris`
- Exécution a nouveau du Hardening SSH

En préparation pour la suite veuillez copier/coller le fichier `.env.template` en `.env` et remplir les champs PROXMOX_DNS, PROXMOX_DNS2, PROXMOX_URL, PROXMOX_NODE et ANSIBLE_PROXMOX_SSH_KEY avec l'emplacement de votre clef SSH.

Ensuite, créer vous un fichier d'inventaire qui sera utilisez par ansible pour accéder a votre serveur proxmox. Pour cela, copier/coller le fichier `inventory.template.yaml` en `inventory.proxmox.yaml` et remplir les champs `ansible_host`, `ansible_user`.

Pour lancer la configuration, resté a la racine du projet git et exécuté la commande suivante :

```bash
task proxmox:setup-proxmox
```

A l'aide des information en sortit de la commande précédente, compléter le fichier `.env` avec les informations PROXMOX_USER, PROXMOX_TOKEN_ID, PROXMOX_TOKEN_SECRET.

Ensuite, un petit restart de votre serveur proxmox s'impose.

## 4. Activer/Désactiver le VPN

Pour activer le VPN, exécuter la commande suivante :

```bash
task proxmox:vpn-local-up
```

Pour désactiver le VPN, exécuter la commande suivante :

```bash
task proxmox:vpn-local-down
```

Le nom `local` a pour cible de différencier une configuration pour le noeud proxmox des possible configuration pour les serveur Kubernetes.
