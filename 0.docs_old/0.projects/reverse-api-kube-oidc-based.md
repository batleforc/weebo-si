# Reverse Oidc Kube Api [TO-DO]

Reverse proxy based on the Kube api.

Has a list of OIDC Provider, check the token based on certain claim, if the claim match redirect to the good Kube Api.

Can have XXX Provider, need to be capable to handle HTTPs/Ws/Other.

## Stack Technique

- Configuration dynamique
  - CRD
    - basé sur [AuthenticationConfiguration](https://kubernetes.io/docs/reference/access-authn-authz/authentication/#using-authentication-configuration) ?
    - Certificat du cluster (possible MTLS ?)
    - metadata
- Authentification
  - Validation du token via les paramètre AuthenticationConfiguration
  - Pas d'impersonate
- Extensions Kubectl
- Path
  - /
    - Interface de l'application
    - Authentification
      - In-App OIDC
        - 1 cluster reverse proxy == 1 Group OIDC
      - Reverse proxy OIDC
        - equivalent oc login --web => Callback server local
        - equivalent oc login --token --api => Token retourner par l'interface
  - /api
    - Internal api of the reverse proxy
  - /cluster/{CLUSTER_NAME}
    - Proxy to the cluster api
- Rust
  - Dois êtes scalable a l'infinis (Redis centralisé ?)
  - Pas d'impersonate (Ouais c'est un besoin de sécurité)
  - Actix
  - Configuration depuis l'ETCD
  - Support HTTP/2 / WebSocket
  - RateLimit configurable (Fail2Ban like aussi)
  - Monitoring / Metrics
  - Support du [CEL (Common Expression Language)](https://github.com/cel-rust/cel-rust) ? Pas sur que ce soit nécessaire d'aller jusque la.

## Status

### Stream 11 OCTOBRE 2025

- [x] CRD
- [x] Couche de tracing basique
- [x] Base de l'api (Swagger auto généré, instrumentation)
- [x] Listener d'event Kube
- [x] Connection basique a un REDIS
