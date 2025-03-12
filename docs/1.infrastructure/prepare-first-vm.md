# Préparation pour nos VMs Talos

## Objectif

- Mettre en cache les iso de Talos (Iso Metal et NoCloud)
- Créer des templates de VM Talos (Toujours Metal et NoCloud)

## Let's do it

### Prérequis

Les deux étapes précédentes doivent être réalisées, [la préparation de votre poste de travail](/weebo-si/1.infrastructure/prepare-pc) et [la préparation du serveur Proxmox](/weebo-si/1.infrastructure/prepare-server).

### Exécution

```bash
task talos:init
```

### Résultat

Vous aurez maintenant deux iso de talos dans le noeud identifié ainsi que deux templates de VM Talos.

![prepare-template](/public/1.infrastructure/prepare-first-vm-template.png)

![prepare-iso](/public/1.infrastructure/prepare-first-vm-iso.png)

## Kesako ?

Télécharger des iso automatiquement et créer des templates de VM Talos c'est bien, mais comment ça marche ?

### Terraform to rule them all

Avant de commencer, il est important de comprendre que Terraform est un outil d'IaC (Infrastructure as Code) qui permet de gérer des infrastructures de manière déclarative. Cela signifie que vous décrivez l'état souhaité de votre infrastructure dans des fichiers de configuration Terraform, et Terraform se charge de mettre en place et de tenter de maintenir cette état a chaque exécution du script.

Je ne rentrerais pas dans les détails des mécanique de Terraform, mais si vous souhaitez en savoir plus, je vous invite à consulter la [documentation officielle](https://developer.hashicorp.com/terraform/docs) ou [la formation de Stéphane Robert](https://blog.stephane-robert.info/docs/infra-as-code/provisionnement/terraform/introduction/).

Le code Terraform que nous allons abordé ce situe dans le dossier `0.terraform/download-iso-talos` et est découper en 4 fichiers :

- `main.tf` : Fichier principal qui contient la configuration de notre provider et les modules à utiliser.
- `iso.tf` : Fichier qui contient la configuration pour télécharger les iso de Talos.
- `proxmox.tf` : Fichier qui va s'occuper du téléchargement des iso sur le serveur Proxmox.
- `talos-template.tf` : Fichier qui va s'occuper de créer les templates de VM Talos.

### main.tf

Ce fichier définis deux providers:

- [`talos`](https://registry.terraform.io/providers/siderolabs/talos/latest/docs) : Provider qui va nous permettre d'interagir/préparer tout ce qui est en rapport avec Talos.
- [`proxmox`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs) : Provider qui va nous permettre d'interagir avec notre serveur Proxmox.

Ce fichier définis aussi cinque variables :

- `proxmox_api` : L'adresse de l'API de notre serveur Proxmox, elle est par défaut mapper sur la variable d'environnement `PROXMOX_API`.
- `proxmox_api_token` : Le token d'authentification de notre serveur Proxmox, il est par défaut mapper sur différente variable d'environnement via Taskfile ce qui donne `${PROXMOX_USER}!${PROXMOX_TOKEN_ID}=${PROXMOX_TOKEN_SECRET}`.
- `proxmox_ssh_username` : Le nom d'utilisateur pour se connecter en SSH sur notre serveur Proxmox, il est demandé mais pas utilisé.
- `proxmox_node_name` : Le nom du noeud sur lequel on va télécharger les iso et créer les templates de VM Talos, il est mappé sur la variable d'environnement `PROXMOX_NODE`.
- `talos_version` : La version de Talos que l'on souhaite télécharger.

### iso.tf

Ce fichier définis quatre objet :

#### `talos_image_factory_extensions_versions.extensions_list`

Cet object permet de définir la version de talos ainsi que les extensions que l'on souhaite installer, ici on souhaite ajouter le `qemu-guest-agent` qui va permettre a proxmox de communiquer avec la VM.

#### `talos_image_factory_schematic.schematic_qemu`

Le schematic est un objet qui va permettre de customiser plus en profondeur notre configuration d'iso, ici on va ajouter le `qemu-guest-agent` ainsi que les paramètres kernel comme `-net.ifnames=0` pour éviter que les interfaces réseaux ne soit renommé automatiquement. Cette ajout créer un schema qui sera utilisé pour obtenir les url de téléchargement des iso. Pour plus d'info, vous pouvez vous diriger vers la [factory de Talos](https://www.talos.dev/v1.9/learn-more/image-factory/).

#### `talos_image_factory_urls.[metal,nocloud]`

Ces deux objets permettent de récupérer les différentes url de téléchargement fournis par la factory de Talos. Parmi ces url, on retrouve l'url de téléchargement de l'iso Metal et de l'iso NoCloud.

### proxmox.tf

Ce fichier définis deux objet :

#### `proxmox_virtual_environment_download_file.talos_[metal,nocloud]`

Ces deux objets qui vont déclencher un téléchargement de l'iso via lien HTTP sur le serveur Proxmox. Pour cela, on utilise le module [`virtual_environment_download_file`](https://registry.terraform.io/providers/bpg/proxmox/latest/docs/resources/virtual_environment_download_file) qui va permettre de télécharger un fichier sur le serveur Proxmox.

Dans cette objet on lui définis que c'est un fichier iso, l'url de téléchargement, le noeud sur lequel on va télécharger l'iso, et le nom du fichier.

L'avantage de cette méthode est qu'elle n'est pas limiter a télécharger des iso de Talos, mais peut être utilisé pour télécharger n'importe quel iso ou fichier.

### talos-template.tf

Ici, on va définir deux objets resource de type `proxmox_virtual_environment_vm`, cette objet permet autant de créer une VM ou un template de VM sur le serveur Proxmox. Les deux ressources sont des templates de VM pour talos utilisant les iso téléchargé précédemment (en utilisant les ressource pour nommer directement dans la définition, terraform va attendre la fin du téléchargement avant de créer les objets).

Ces objets définissent les différentes propriétés de la VM, comme le nom, le noeud sur lequel elle doit être créé, le disque, la mémoire, le CPU, le réseau, etc.

```hcl
resource "proxmox_virtual_environment_vm" "talos_template_metal" {
  name        = "talos-template-metal"
  description = "Talos template for metal"
  # Tags pour faciliter la recherche
  tags        = ["talos", "template", "terraform", "weebo-si", "metal"]
  node_name   = var.proxmox_node_name
  vm_id       = "9999" # 9998 pour le template NoCloud

  template = true

  agent {
    enabled = true
  }

  # On définis les propriétés de la VM
  # celle ci seront modifiable lors de la création de la VM
  # idem pour la mémoire, le CPU, le disque, le réseau, etc.
  cpu {
    cores   = 1
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
    floating  = 2048
  }

  disk {
    datastore_id = "local"
    interface    = "scsi0"
    replicate    = false
    backup       = false
    aio          = null
  }

  cdrom {
    file_id   = proxmox_virtual_environment_download_file.talos_metal.id
    interface = "ide2"
  }

  network_device {
    # On utilise le bridge vmbr1 pour le réseau
    # Celui ci porte la configuration DHCP
    bridge = "vmbr1"
  }

  # On définis l'ordre de boot
  # Celui ci permet a Talos de démarrer sur le CDROM (ide2)
  # quand l'os n'est pas encore installer puis sur le disque (scsi0)
  boot_order = ["scsi0", "ide2"]
}
```

La base de cette configuration viens de la [documentation de Stéphane robert autour du provisionnement d'une VM avec terraform](https://blog.stephane-robert.info/docs/virtualiser/type1/proxmox/terraform/), j'ai par contre adapté cette configuration pour automatiser tout le processus de téléchargement et de création de template de VM Talos sans avoir a manipuler directement le serveur Proxmox. Cette automatisation ma permis d'expérimenter dans un premier temps son guide formateur puis de l'adapter a mes besoins d'automatisme et d'état prédictible.
