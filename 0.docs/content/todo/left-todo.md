# What's left to do ?

## Bone of the project

- [ ] Remplacer le setup actuel d'Authentik avec l'opérateur [Weebo-Authentik](https://github.com/batleforc/weebo-authentik)
  - [ ] Migrer Authentik vers CNPG
  - [ ] Migrer les utilisateurs et groupes existants vers l'opérateur
  - [ ] Migrer les applications existantes vers l'opérateur
- [ ] [ProxyAuthK8S](https://github.com/batleforc/ProxyAuthK8S)
  - [ ] Point d'accés externe au cluster Kubernetes pour l'authentification OIDC
  - [ ] Rejeter toutes requêtes qui ne viendrais pas de ProxyAuthK8S ?
- [ ] Setup RustFS
  - [ ] [OIDC](https://docs.rustfs.com/fr/security-compliance/oidc/keycloak)
  - [ ] Terraform ? New Operator ?
- [ ] [Angos](https://angos.dev/docs/how-to/deploy-kubernetes#prerequisites)
  - [ ] [OIDC user](https://angos.dev/docs/how-to/configure-generic-oidc) : Allow users to login with OIDC
  - [ ] [OIDC Kube](https://angos.dev/docs/how-to/configure-kubernetes-oidc) : Allow Kubernetes to authenticate with OIDC (e.g. Create a Dockerconfigjson from service account that can be used to pull images from a private registry)
  - [ ] [OIDC CI](https://angos.dev/docs/how-to/configure-github-actions-oidc) : Directly push images to angos registry from GitHub Actions using OIDC
- [ ] [Batlehub](https://batleforc.git.batleforc.fr/batlehub/)
  - [ ] [OIDC](https://batleforc.git.batleforc.fr/batlehub/guide/admin-config.html#auth) : Allow users to login with OIDC
  - [ ] [OIDC Kube](https://batleforc.git.batleforc.fr/batlehub/guide/admin-config.html#kubernetes-service-accounts) : Allow Kubernetes to authenticate with OIDC (e.g. Create a configuration in pod from service account that can be used to pull artifacts from a private registry)
  - [ ] [OIDC CI](https://batleforc.git.batleforc.fr/batlehub/guide/admin-config.html#github-actions) : Directly push artifacts to batlehub registry from GitHub Actions using OIDC (Like VsCode Extension or other)
- [ ] [Kuberarmor](https://kubearmor.com/)
- [ ] [Kloak](https://une-tasse-de.cafe/blog/kloak/)
- [ ] [Weebo Si Hardening](https://github.com/batleforc/weebo-si-hardening)
  - [ ] NetPolicy
  - [ ] DWOC restrictions
  - [ ] Image Pull Policy
  - [ ] Image Registry
  - [ ] Package Registry
- [ ] [Eclipse Che](https://www.eclipse.org/che/)

## Documentation

- [ ] Installation Guide
- [ ] User Guide

- [ ] Big Picture Infra
- [ ] Big Picture Database
- [ ] Big Picture Monitoring
- [ ] Big Picture Security
- [ ] Big Picture Dev Environment

- [ ] Macro Infra
  - [ ] Kubernetes/Talos
  - [ ] Cilium
  - [ ] Authentification
    - [ ] Authentik
      - [ ] Weebo-Authentik Operator
      - [ ] Outpost
      - [ ] PreAuth-Proxy
    - [ ] Dex
  - [ ] Vault
    - [ ] PKI
    - [ ] Secrets
    - [ ] External Secrets
  - [ ] ArgoCD
  - [ ] Cert-Manager / Trust Manager
  - [ ] Storage
    - [ ] Longhorn
    - [ ] LocalStorage
  - [ ] ProxyAuthK8S
- [ ] Database
  - [ ] PostgreSQL
    - [ ] CNPG
  - [ ] MongoDB
    - [ ] MongoDB Operator
  - [ ] ClickHouse
    - [ ] ClickHouse Operator
  - [ ] RustFS
    - [ ] [RustFS Operator](https://github.com/rustfs/operator)
    - [ ] [OIDC](https://github.com/rustfs/operator/issues/207)
- [ ] Monitoring
  - [ ] ClickStack
  - [ ] OpenTelemetry eBPF Instrumentation
  - [ ] Otel Collector
- [ ] Registry
  - [ ] Batlehub
  - [ ] Angos
- [ ] Security
  - [ ] Kloak
  - [ ] KubeArmor
  - [ ] Weebo-SI Hardening
- [ ] Dev Environment
  - [ ] Eclipse Che
  - [ ] Future components ?
    - [ ] Plateform ingineering ?
    - [ ] Git provider Integration ?
    - [ ] podman build/run ?
