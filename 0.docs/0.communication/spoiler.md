# Spoilers

## LoadBalancer VM

```mermaid
flowchart TB
 subgraph chenode["chenode"]
        ControlPlane["ControlPlane"]
        Node1["Node1"]
        NodeX["NodeX"]
  end
 subgraph s1["che-Cluster"]
        che("Eclipse Che")
        kcsi("Kubevirt CSI")
        traefik2("Traefik")
        cilium2("Cilium")
        cm2("Cert Manager")
        chenode
  end
 subgraph subGraph1["Weebo4CP Mono node Talos"]
        kvirt("Kubevirt")
        capi("Cluster Api")
        auth("Authentik")
        traefik("Traefik")
        cilium("Cilium")
        kcsic("Kubevirt CSI Controller")
        cm1("Cert Manager")
        argo("ArgoCD")
        s1
  end
 subgraph Weebo4SI["Weebo4SI"]
        subGraph1
  end
    kcsi --> kcsic
    user>"User"] L_user_cilium_0@--> cilium
    cilium L_cilium_traefik_0@--> traefik
    traefik L_traefik_cilium2_0@--> cilium2 & cm1 & argo
    traefik <--> auth
    cilium2 L_cilium2_traefik2_0@--> traefik2
    traefik2 L_traefik2_che_0@--> che & cm2
    argo --> capi
    capi --> kvirt
    kvirt <--> kcsic
    auth L_auth_argo_0@<--> argo & chenode
    che <--> auth
    kvirt --> chenode

    style s1 fill:#000000
    style subGraph1 fill:#757575
    style Weebo4SI fill:#616161
    linkStyle 1 stroke:#D50000,fill:none
    linkStyle 2 stroke:#D50000,fill:none
    linkStyle 3 stroke:#D50000,fill:none
    linkStyle 7 stroke:#D50000,fill:none
    linkStyle 8 stroke:#D50000,fill:none

    L_user_cilium_0@{ animation: slow } 
    L_cilium_traefik_0@{ animation: slow } 
    L_traefik_cilium2_0@{ animation: slow } 
    L_cilium2_traefik2_0@{ animation: slow } 
    L_traefik2_che_0@{ animation: slow } 
    L_auth_argo_0@{ animation: none } 

```

## Netbird X Talos

```bash
curl -s --data-binary @./0.updatecli/shell/talos-scheme.sub.yaml https://factory.talos.dev/schematics
```

- Talos Url : <factory.talos.dev/openstack-installer/489b8c4c135880c4d03864c0c46871e71c16f39375a5662ab90b475bb919bf08:v1.11.2>
- Harbor Url : <harbor.4.weebo.fr/cache-talos/openstack-installer/489b8c4c135880c4d03864c0c46871e71c16f39375a5662ab90b475bb919bf08:v1.11.2>
- Extensions Url : <ghcr.io/siderolabs/netbird:0.57.1>
- Netbird Extensions doc : <https://github.com/siderolabs/extensions/tree/main/network/netbird>
- [Using Harbor has a talos cache registry](https://www.talos.dev/v1.11/talos-guides/configuration/pull-through-cache/)

### Build Command

```bash
docker run --rm -t -v $PWD/_out:/out ghcr.io/siderolabs/imager:v1.11.2 installer --platform=openstack --extra-kernel-arg net.ifnames=0 --system-extension-image ghcr.io/siderolabs/netbird:0.57.1 --system-extension-image ghcr.io/siderolabs/iscsi-tools:v0.2.0 --system-extension-image ghcr.io/siderolabs/qemu-guest-agent:10.0.2 --system-extension-image ghcr.io/siderolabs/util-linux-tools:2.41.1 --system-extension-image ghcr.io/siderolabs/mei:v1.11.2 --system-extension-image ghcr.io/siderolabs/intel-ucode:20250812
```

```bash
docker run --rm -t -v ~/.docker/config.json:/root/.docker/config.json -e DOCKER_CONFIG=/root/.docker -v $PWD/_out:/out harbor.4.weebo.fr/cache-ghub/siderolabs/imager:v1.11.2 installer --platform=openstack --extra-kernel-arg net.ifnames=0 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/netbird:0.57.1 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/iscsi-tools:v0.2.0 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/qemu-guest-agent:10.0.2 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/util-linux-tools:2.41.1 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/mei:v1.11.2 --system-extension-image harbor.4.weebo.fr/cache-ghub/siderolabs/intel-ucode:20250812
```

### Extensions

- <https://github.com/siderolabs/extensions/pkgs/container/iscsi-tools> : 0.2.0
- <https://github.com/siderolabs/extensions/pkgs/container/netbird> : 0.57.1
- <https://github.com/siderolabs/extensions/pkgs/container/qemu-guest-agent> : 10.0.2
- <https://github.com/siderolabs/extensions/pkgs/container/util-linux-tools> : 2.41.1
- <https://github.com/siderolabs/extensions/pkgs/container/mei> : v1.11.2
- <https://github.com/siderolabs/extensions/pkgs/container/intel-ucode> : 20250812
