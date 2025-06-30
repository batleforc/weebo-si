# ALL IN ONE

Le but est de provisionner un noeud Dédié OVH avec une iso Talos et de rentre le setup le plus simple possible avec des techno que je ne maîtrise pas encore.

## Techno a apprendre

- Pulumi

## Existant

- Solutions en Terraform permettant l'installation d'un noeud OVH avec une qcow2 Talos
- Bootstrap de l'env Talos puis installation de Cilium

## GOAL

- Provisionnement automatisé via Github Action
- Installation de Talos sur le dédié
- Bootstrap de Talos
- Support IPV4 ++ IPV6
- Installation de Cilium
- Installation d'ArgoCD

## Link

- [Talos Pulumi](https://www.pulumi.com/registry/packages/talos/)
- [Cilium Pulumi](https://www.pulumi.com/registry/packages/cilium/)
- [Ovh Pulumi](https://www.pulumi.com/registry/packages/ovh/)
- [Kubernetes Pulumi](https://www.pulumi.com/registry/packages/kubernetes/)
- [ArgoCD Pulumi](https://www.pulumi.com/registry/packages/argocd/)
- [UpdateCLI Golang](https://www.updatecli.io/docs/plugins/autodiscovery/golang/)
- [Github Action](https://www.pulumi.com/docs/iac/using-pulumi/continuous-delivery/github-actions/)
- [Argocd x Pulumi](https://www.pulumi.com/docs/iac/using-pulumi/continuous-delivery/argocd/)