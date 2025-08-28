# Reverse Oidc Kube Api [TO-DO]

Reverse proxy based on the Kube api.

Has a list of OIDC Provider, check the token based on certain claim, if the claim match redirect to the good Kube Api.

Can have XXX Provider, need to be capable to handle HTTPs/Ws/Other.

## Stack Technique

- Rust
  - Dois êtes scalable a l'infinis
  - Pas d'impersonate
  - Actix
  - Redis
    - Stockage des jeton valide (?) pour X seconde puis revalidation
    - Stockage de la configuration (sélecteur de claim, Provider, client secret, client id)
