# Kamalos

Kamalos est le nom du POC visant a déployer un cluster Kamaji x Talos x Kubevirt x ArgoCD.

Cette configuration est basé sur le [déploiement Sidecar CSR Signer de Talos](https://github.com/clastix/talos-csr-signer/blob/master/docs/sidecar-deployment.md) et utilise Kubevirt pour créer des machines virtuelles Talos servant de nœuds Worker au cluster Kamaji.

## Prérequis

- Un cluster Kubernetes
- Kubevirt installé sur le cluster Kubernetes
- ArgoCD installé sur le cluster Kubernetes
- Cilium comme CNI
- Helm 3
- kubectl
- Kubeadm
- Talosctl

## Installation

### 0. Nota Bene

Les scripts fournis utilisent la commande `task aio:kubectl --` pour exécuter les commandes kubectl dans le cluster HOST. Il est possible d'adapter les scripts en remplaçant cette commande par `kubectl --kubeconfig=./path/to/kubeconfig` si vous souhaitez exécuter les commandes directement.

### 1. Création des secrets

Avant de déployer Kamaji il est nécessaire de préparer les secrets nécessaires en créant une configuration Talos puis en créant le secret dans kubernetes.

```bash
talosctl gen secrets -o ./tmp/secrets.yaml --force # Génère la configuration Talos
./secret.sh # Créer le secret correspondant dans le namespace kamalos
```

### 2. Créer l'application ArgoCD

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: kamalos
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  project: default
  source:
    repoURL: 'https://github.com/batleforc/weebo-si'
    path: 'all-in-one.argo/helm/kamalos'
    helm:
      releaseName: kamalos
  destination:
    name: in-cluster
    namespace: 'kamalos'
  syncPolicy:
    syncOptions:
    - RespectIgnoreDifferences=true
    - CreateNamespace=true
    - ServerSideApply=true # Nécessaire pour les CRD
```

::: warning

Il est important de noter que l'ordre de déploiement des élément dans l'application n'est pas gérer actuellement. Il est donc nécessaire d'arrêter le déploiement et de s'assurer du déploiement dans l'ordre suivant :

- Kamaji
- issuer kamalos
- Cert-grpc-kamalos
- cp-kamalos*.yaml
- worker-kamalos.yaml

:::

### 3. Récupérer le Kubeconfig et appliquer les droits d'accès

Une fois le déploiement terminé, il est possible de récupérer le kubeconfig du cluster kamalos en utilisant la commande suivante :

```bash
kubectl get secret kamalos-admin-kubeconfig -n kamalos \
  -o jsonpath='{.data.admin\.conf}' | base64 -d > ./tmp/kamalos-kamalos.kubeconfig
```

Il est ensuite possible d'utiliser ce kubeconfig pour se connecter au cluster kamalos :

```bash
kubectl --kubeconfig=./tmp/kamalos-kamalos.kubeconfig get nodes
```

Maintenant que vous avez accés au cluster Kamalos, il est nécessaire d'appliquer les droits RBAC permettant au worker de récupérer les ressources nécessaires :

```bash
kubectl --kubeconfig=./tmp/kamalos-kamalos.kubeconfig apply -f endpointslices.yaml
```

Cette commande creer un ClusterRole et un RoleBinding permettant au worker Kamalos d'accéder aux EndpointSlices `kubernetes` dans le namespace `default`.

### 4. Création de la configuration Talos a destination des workers

Le script `gen-talosconfig.sh` permet de générer la configuration Talos pour les workers. Celui-ci récupère directement les ips des workers créés dans Kubevirt dans le NS Kamalos et génère la configuration Talos en conséquence.

```bash
./gen-talosconfig.sh
```

### 5. Bootstrap des workers Kamalos

Lors de la créations de l'application Kamalos, 2 workers ont été créés dans Kubevirt. Il est maintenant nécessaire de les bootstraper avec Talosctl en utilisant la configuration générée précédemment.

```bash
./gen-worker-conf.sh
```

Cette commande va bootstraper les X workers Kamalos en utilisant Talosctl et une configuration récupérant le token Kubeadm.

### 6. Installation du CNI

Deux CNI sont testés et validé avec Kamalos : Cilium et Flannel. Le choix de la raison vous appartient (Choisissez Cilium).

#### Cilium

Le script `add-cilium.sh` permet d'installer Cilium dans le cluster Kamalos en utilisant le kubeconfig généré précédemment. Il part du principe que le cluster HOST utilise également Cilium.

```bash
./add-cilium.sh
```

#### Flannel

Le script `add-flannel.sh` permet d'installer Flannel dans le cluster Kamalos en utilisant le kubeconfig généré précédemment. Ce script est celui proposé dans la documentation talos-csr-signer.

```bash
./add-flannel.sh
```

### 7. Vérification du cluster

Une fois le CNI installé, il est possible de vérifier que le cluster Kamalos est opérationnel en utilisant la commande suivante :

```bash
kubectl --kubeconfig=./tmp/kamalos-kamalos.kubeconfig get pods -A
```

Après quelques minutes, tous les pods devraient être en état `Running`.

## Ressources

- [Talos CSR Signer](https://github.com/clastix/talos-csr-signer)
- [Kamaji](https://github.com/clastix/kamaji)
- [Kubevirt](https://kubevirt.io/)
- [Cilium](https://cilium.io/)
- [Flannel](https://github.com/flannel-io/flannel)
- [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)
- [Talos](https://talos.dev/)
