# Spec Auth system

- 1 application
  - 1 role Admin
  - 1 role User
  - Si pas de role, pas d'accès

- 1 Équipe
  - Groupes
    - 1 Groupe OPS
      - PROD: RW
      - HP : RW
    - 1 Groupe Lead
      - PROD : R
      - HP : RW
    - 1 Groupe Dev
      - PROD: NADA
      - HP : R - Deploy contrôler
  - 2 Cluster
    - Prod
    - Hors Prod
  - Un accès a certaine app

- 1 Groupe SUPER ADMIN
  - RW CAPI ++ Main Cluster
- 1 Groupe Admin
  - RW Main Cluster ++ R contrôler sur Capi
