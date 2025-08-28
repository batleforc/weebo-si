# Installation de KubeVirt CSI sur Talos

## Objectifs

- Mettre à disposition des PVC du cluster Infra à destination du cluster KubeVirt
- Rendre les données persistantes, peu importe les redémarrages induits par la Cluster API

## Prérequis

- Avoir un cluster Talos fonctionnel (par exemple en suivant le [guide Weebo-SI](./initOvhTalos.md))
- Avoir installé KubeVirt sur Talos en suivant [le guide Weebo-SI](./installationKubevirt.md)
- Avoir un cluster Cluster API fonctionnel en suivant [le guide Weebo-SI](./installationCapi.md)
