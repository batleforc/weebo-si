# Reverse Oidc Kube Api

Reverse proxy based on the kube api.

Has a list of OIDC Provider, check the token based on certain claim, if the claim match redirect to the good Kube Api.

Can have XXX Provider, need to be hable to handle HTTPs/Ws/Other.

## Stack Technique

- Rust
  - Dois êtes scalable a l'infinis
  - Pas d'impersonate
  - Actix
  - Redis
    - Stockage des jeton valide (?) pour Xseconde puis revalidation
    - Stockage de la configuration (selecteur de claim, Provider, client secret, client id)
