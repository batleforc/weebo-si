# Installation de Talos sur OVH via Pulumi
<!-- no toc -->
## Objectif

- Installer Talos x Cilium sur un serveur Bare Metal OVH via Pulumi

## Prérequis

- Avoir un compte OVH
- Avoir installé Pulumi sur votre poste de travail
- Avoir un token pour [l'API OVH](https://api.ovh.com/createToken/?GET=/*&POST=/*&PUT=/*&DELETE=/*)
- Avoir un serveur Bare Metal OVH avec le nom du serveur `nsXXXXXX.ip-XXX-XXX-XXX.eu`

## Étapes

<!-- no toc -->
- [1. Cloner le dépôt Git](#1-cloner-le-dépôt-git)
- [2. Copier/Coler le fichier .env.template en .env](#2-copiercoler-le-fichier-envtemplate-en-env)
- [3. Remplir le fichier .env avec vos informations OVH](#3-remplir-le-fichier-env-avec-vos-informations-ovh)
- [4. Lancer la commande `task aio:up`](#4-lancer-la-commande-task-aio-up)
- [5. Enjoy !](#5-enjoy-)

## 1. Cloner le dépôt Git

Jusque là, tout est standard. Vous pouvez cloner le dépôt Git où vous le souhaitez sur votre poste de travail.

```bash
git clone https://github.com/batleforc/weebo-si.git
cd weebo-si
```

## 2. Copier/Coler le fichier .env.template en .env

```bash
cp .env.template .env
```

## 3. Remplir le fichier .env avec vos informations OVH

```bash
nano .env
```

```ini
## ArgoCD

ARGO_GITHUB_TOKEN="JE_SUIS_UN_TOKEN_GITHUB"

## Ovh
OVH_ENDPOINT="kimsufi-eu"
OVH_APPLICATION_KEY="YOUR_OWN_APPLICATION_KEY"
OVH_APPLICATION_SECRET="YOUR_OWN_APPLICATION_SECRET"
OVH_CONSUMER_KEY="YOUR_OWN_CONSUMER_KEY"

SERVER_NAME="nsxxxxxx.ip-xx-xxx-xxx.eu"
```

## 4. Lancer la commande task aio up

```bash
task aio:up
```

La commande `task aio:up` va en réalité exécuter deux scripts Pulumi:

- `task up-aio` : Permet le provisionnement du BareMetal Ovh et l'installation de Talos ainsi que Cilium, cette applications ce trouve dans le dossier `0.pulumi/all-in-one`
- `task up-app` : Permet la configuration de Cilium et l'installation d'ArgoCD puis l'installation de la première application, cette application se trouve dans le dossier `0.pulumi/app`

### `task up-aio` ou préparation du BareMetal OVH

Le premier script Pulumi s'exécute dans le dossier `0.pulumi/all-in-one` et effectue les actions suivantes: (Certaine ligne de code seront couper mais facilement retrouvable dans le `main.go`)

1. Récupération du schematic Talos et préparation de l'url Qcow2.

```go
// Définition des paramètres de personnalisation de Talos
tmpYamlSchema, err := yaml.Marshal(map[string]interface{}{
  "customization": map[string]interface{}{
    "extraKernelArgs": []string{
      "net.ifnames=0",
    },
    "systemExtensions": map[string]interface{}{
      "officialExtensions": []string{
        "siderolabs/iscsi-tools",
        "siderolabs/util-linux-tools",
        "siderolabs/intel-ucode",
        "siderolabs/mei",
      },
    },
  },
})
```

```go
// Construction de l'URL Qcow2 sur une base metal
qcow2Url := urlResult.SchematicId().ApplyT(func(schematicId string) (string, error) {
  ctx.Export("schematicId", pulumi.String(schematicId))
  return fmt.Sprintf("https://factory.talos.dev/image/%s/%s/%s-amd64.qcow2", schematicId, talosVersion, platform), nil
}).(pulumi.StringOutput)
```

2. Lancement de l'installation de Talos directement sur le Bare Metal OVH.

```go
reinstall, err := dedicated.NewServerReinstallTask(ctx, "reinstallTalos", &dedicated.ServerReinstallTaskArgs{
  // Nom du serveur nsxxxxxx.ip-xx-xxx-xxx.eu
  ServiceName: pulumi.String(serviceName),
  // On utilise l'option OVH pour apporter notre propre Image
  Os:          pulumi.String("byoi_64"),
  Customizations: &dedicated.ServerReinstallTaskCustomizationsArgs{
    // On définis le petit nom du serveur, car qui n'aime pas nommer ces serveurs
    Hostname:          pulumi.String(nodeName),
    ImageType:         pulumi.String("qcow2"),
    ImageUrl:          qcow2Url,
    // MERCI ! https://github.com/siderolabs/talos/issues/11236
    EfiBootloaderPath: pulumi.String("\\EFI\\BOOT\\BOOTX64.EFI"),
  },
})
```

3. Préparation de la configuration de Talos a partir des information fournis par l'API OVH.

```go
// Récupération des information réseau du noeud, style IPV4/IPV6, Gateway, etc
serverNetwork, err := dedicated.GetServerSpecificationsNetwork(ctx, &dedicated.GetServerSpecificationsNetworkArgs{
  ServiceName: serviceName,
}, nil)
```

```go
// Préparation du bootstrap Talos en incluant l'ip du noeud pour pouvoir le joindre
configuration := machine.GetConfigurationOutput(ctx, machine.GetConfigurationOutputArgs{
  ClusterName:       pulumi.String(fmt.Sprintf("%s-cluster", nodeName)),
  MachineType:       pulumi.String("controlplane"),
  ClusterEndpoint:   pulumi.String(fmt.Sprintf("https://%s:6443", serverNetwork.Routing.Ipv4.Ip)),
  MachineSecrets:    secrets.MachineSecrets,
  TalosVersion:      pulumi.String(talosVersion),
  KubernetesVersion: pulumi.StringPtr(kubeVersion),
})
```

```go
// Création du patch Talos appliquant les dernière configuration
jsonPatchConfig := urlResult.Urls().Installer().ApplyT(func(installerUrl string) (string, error) {
  swapJsonPatchConfig, err := json.Marshal(map[string]interface{}{
    "cluster": map[string]interface{}{
      "allowSchedulingOnControlPlanes": true,
      "extraManifests": []string{
        // Installation du metrics serveur pour remonter des métriques
        "https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml",
        // Installation du Cert Approver pour permettre une rotation sécurisée des certificats
        "https://raw.githubusercontent.com/alex1989hu/kubelet-serving-cert-approver/main/deploy/standalone-install.yaml",
      },
      "network": map[string]interface{}{
        "cni": map[string]interface{}{
          // Pas de CNI nous allons installer Cilium par la suite
          "name": "none",
        },
        "podSubnets": []string{
          "10.244.0.0/16",
          "fd00:10:244::/56",
        },
        "serviceSubnets": []string{
          "10.96.0.0/12",
          "fd00:10:96::/112",
        },
        "apiServer": map[string]interface{}{
            "certSANs": []string{
              // Et on ajoute quelque point d'entrée au certificat
              serverNetwork.Routing.Ipv4.Ip,
              strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
              dnsName,
            },
          },
    },
      "machine": map[string]interface{}{
        // Skip d'autre option
        "network": map[string]interface{}{
            // Une surcharge du petit nom donnée plus haut !
            "hostname": fmt.Sprintf("%s-controlplane", nodeName),
            "interfaces": []map[string]interface{}{
              // Et toute la magie du réseau OVH entre en action
                {
                    "addresses": []string{
                        // Pas de DHCPv6 donc nécessiter de trouver le bon masque
                        strings.ReplaceAll(serverNetwork.Routing.Ipv6.Ip, "/128", "/48"),
                    },
                    // L'option dans la customisation Talos `net.ifnames=0` rend l'interface eth0 persistante
                    "interface": "eth0",
                    "dhcp":      true,
                    "dhcpOptions": map[string]interface{}{
                        // Pour le DHCPv4 tout est ok il suffit de l'activer
                        "ipv4": true,
                        "ipv6": false,
                    },
                    "routes": []map[string]interface{}{
                        // La route par défaut pour le V6
                        {
                            "network": "::/0",
                            "gateway": serverNetwork.Routing.Ipv6.Gateway,
                        },
                    },
                },
            },
        }
      }
    }
  })
})
```

4. Bootstrap du nœud Talos fraîchement installé.

```go
// Création de la configuration a partir du patch
configurationApply, err := machine.NewConfigurationApply(ctx, "configurationApply", &machine.ConfigurationApplyArgs{
  ClientConfiguration:       secrets.ClientConfiguration,
  MachineConfigurationInput: configuration.MachineConfiguration(),
  Node:                      pulumi.String(serverNetwork.Routing.Ipv4.Ip),
  Endpoint:                  pulumi.String(serverNetwork.Routing.Ipv4.Ip),
  ConfigPatches: pulumi.StringArray{
    jsonPatchConfig,
    pulumi.String(string(jsonPatchUserVolume)),
  },
}, pulumi.DependsOn([]pulumi.Resource{
  reinstall,
}))
if err != nil {
  return fmt.Errorf("failed to create configuration apply: %w", err)
}

// Envoie de la configuration au nœud Talos uniquement
// une fois qu'il est installer sinon on attend patiemment
bootstrap, err := machine.NewBootstrap(ctx, "bootstrap", &machine.BootstrapArgs{
  Node:                pulumi.String(serverNetwork.Routing.Ipv4.Ip),
  ClientConfiguration: secrets.ClientConfiguration,
}, pulumi.DependsOn([]pulumi.Resource{
  configurationApply,
  reinstall,
}))
```

5. Génération des fichiers Kubeconfig et Talosconfig

```go
// Création du kubeconfig
kubeconfig, err := cluster.NewKubeconfig(ctx, "kubeconfig", &cluster.KubeconfigArgs{
  ClientConfiguration: cluster.KubeconfigClientConfigurationArgs{
    CaCertificate:     secrets.ClientConfiguration.CaCertificate(),
    ClientCertificate: secrets.ClientConfiguration.ClientCertificate(),
    ClientKey:         secrets.ClientConfiguration.ClientKey(),
  },
  Endpoint: pulumi.String(serverNetwork.Routing.Ipv4.Ip),
  Node:     pulumi.String(serverNetwork.Routing.Ipv4.Ip),
}, pulumi.DependsOn([]pulumi.Resource{
  bootstrap,
}))
if err != nil {
  return fmt.Errorf("failed to create kubeconfig: %w", err)
}
// Puis écriture dans le fichier kubeconfig.yaml relatif a l'emplacement du main.go
fileKubeconfig, err := local.NewFile(ctx, "kubeconfig", &local.FileArgs{
  Content:  kubeconfig.KubeconfigRaw,
  Filename: pulumi.String("kubeconfig.yaml"),
}, pulumi.DependsOn([]pulumi.Resource{
  kubeconfig,
}))
if err != nil {
  return err
}
```

6. Installation de Cilium sur le nœud Talos.

```go
// Lecture du fichier cilium-values.yaml issue du values du helm chart
ciliumValues, err := os.ReadFile("cilium-values.yaml")
if err != nil {
  return fmt.Errorf("failed to read cilium values file: %w", err)
}
// Installation du cilium en lui injectant dynamiquement l'adresse de contact du noeud
ciliumInstall, err := cilium.NewInstall(ctx, "ciliumInstall", &cilium.InstallArgs{
  Version: pulumi.String(ciliumVersion),
  Sets: pulumi.StringArray{
    pulumi.Sprintf("k8sServiceHost=%s", serverNetwork.Routing.Ipv4.Ip),
  },
  Values: pulumi.String(string(ciliumValues)),
}, pulumi.DependsOn([]pulumi.Resource{
  // Sans oublier que le kubeconfig dois exister avant de pouvoir installer
  kubeconfig,
  fileKubeconfig,
}))

if err != nil {
  return fmt.Errorf("failed to create Cilium install: %w", err)
}
```

7. Activation de Hubble pour Cilium.

```go
// Installation de Hubble pour Cilium, rien de bien compliquer
_, err = cilium.NewHubble(ctx, "example", &cilium.HubbleArgs{
  Ui: pulumi.Bool(true),
}, pulumi.DependsOn([]pulumi.Resource{
  ciliumInstall,
}))

if err != nil {
  return fmt.Errorf("failed to create Hubble: %w", err)
}
```

### `task up-app` ou l'installation d'ArgoCD

Le second script Pulumi s'exécute dans le dossier `0.pulumi/app` et effectue les actions suivantes: (Certaine ligne de code seront couper mais facilement retrouvable dans le `main.go`)

1. Création de la configuration Cilium LoadBalancerIPPool

De la même manière que pour l'installation, on recupére les information réseau depuis l'API OVH. puis on créer le manifest.

```go
// Create Cilium IpPool
_, err = yamlv2.NewConfigGroup(ctx, "ciliumIpPool", &yamlv2.ConfigGroupArgs{
  Objs: pulumi.Array{
    pulumi.Any(map[string]interface{}{
      "apiVersion": "cilium.io/v2alpha1",
      "kind":       "CiliumLoadBalancerIPPool",
      "metadata": map[string]interface{}{
        "name": "ip-pool",
      },
      "spec": map[string]interface{}{
        "blocks": []map[string]interface{}{
          // Ajout de la plage IPV4 mono noeud
          {
            "start": serverNetwork.Routing.Ipv4.Ip,
            "stop":  serverNetwork.Routing.Ipv4.Ip,
          },
          // Ajout de la plage IPV6 mono noeud
          {
            "start": strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
            "stop":  strings.Replace(serverNetwork.Routing.Ipv6.Ip, "/128", "", -1),
          },
        },
      },
    }),
  },
})
```

2. Mise en place de l'installation ArgoCD

L'installation pour ArgoCD est basé sur l'installation du HelmChart. Cette installation a la particularité d'inclure par avance la partit Oauth2 qui n'est pris en compte qu'une fois le secret correspondant est créer.

```go
argocd, err := helmv4.NewChart(ctx, "argocd", &helmv4.ChartArgs{
  Chart:   pulumi.String("argo-cd"),
  Version: pulumi.String(argoAppsVersion),
  Namespace: ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
    return metadata.Name, nil
  }).(pulumi.StringPtrOutput),
  RepositoryOpts: &helmv4.RepositoryOptsArgs{
    // Installation depuis le repository officiel
    Repo: pulumi.String("https://argoproj.github.io/argo-helm"),
  },
  Values: pulumi.Map{
    "configs": pulumi.Map{
      "cm": pulumi.Map{
        // Injection de la configuration Dex en préparation de l'installation d'Authentik
        "dex.config": pulumi.String(`
connectors:
- type: oidc
  name: Weebo-SI
  id: weebo-si
  config:
    issuer: $argo-dev-auth:url
    clientID: $argo-dev-auth:client_id
    clientSecret: $argo-dev-auth:client_secret
    insecureEnableGroups: true
    requestedScopes:
      - "openid"
      - "profile"
      - "email"
      - "groups"`),
        "url": pulumi.String("https://argo.4.weebo.fr"),
      },
      "params": pulumi.Map{
        "server.insecure": pulumi.Bool(true),
      },
      "rbac": pulumi.Map{
        "scopes": pulumi.String("[groups]"),
        // Ajout des rôles pour les groupes
        "policy.csv": pulumi.String(`g, admin, role:admin
g, dev, role:dev
g, reader, role:readonly
g, weebo_admin, role:admin
g, authentik Admins, role:admin`),
      },
    },
    "global": pulumi.Map{
      // Configuration du DNS correspondant
      "domain": pulumi.String("argo.4.weebo.fr"),
    },
    "server": pulumi.Map{
      "ingress": pulumi.Map{
        "enabled": pulumi.Bool(true),
        "tls":     pulumi.Bool(true),
        "annotations": pulumi.StringMap{
          "cert-manager.io/cluster-issuer": pulumi.String("outbound"),
        },
      },
    },
  },
}, pulumi.DependsOn([]pulumi.Resource{
  argoRedisSecret,
}))
```

3. Création de l'application ArgoCD AIO directement relier a ce repository

```go
// Création de l'application main pointant sur le repo de ce projet
_, err = yamlv2.NewConfigGroup(ctx, "argoCDApp", &yamlv2.ConfigGroupArgs{
Objs: pulumi.Array{
  pulumi.Any(map[string]interface{}{
    "apiVersion": "argoproj.io/v1alpha1",
    "kind":       "Application",
    "metadata": map[string]interface{}{
      "name": "main",
      "namespace": ns.Metadata.ApplyT(func(metadata metav1.ObjectMeta) (*string, error) {
        return metadata.Name, nil
      }).(pulumi.StringPtrOutput),
    },
    "spec": map[string]interface{}{
      "syncPolicy": map[string]interface{}{
        "automated": map[string]interface{}{},
      },
      "destination": map[string]interface{}{
        "namespace": "default",
        "server":    "https://kubernetes.default.svc",
      },
      "project": "default",
      "source": map[string]interface{}{
        "repoURL":        "https://github.com/batleforc/weebo-si.git",
        "path":           "all-in-one.argo/app",
        "targetRevision": "HEAD",
        "directory": map[string]interface{}{
          "recurse": true,
        },
      },
    },
  }),
},
}, pulumi.DependsOn([]pulumi.Resource{
argocd,
}))
```

## 5. Enjoy !

Vous pouvez dès à présent vous connecter a votre cluster Talos via kubectl.

```bash
task aio:kubectl -- get node
```
