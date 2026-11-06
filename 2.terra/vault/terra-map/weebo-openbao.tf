# weebo-openbao (RFC 0007 §6.1) : l'operateur qui cree, dans des namespaces
# OpenBao, les espaces des orgs et des utilisateurs. Sa policy reste ici, dans
# Terraform, pour toujours : l'operateur ne peut pas s'accorder ses propres
# droits. Le device d'audit (2.argo/helm/vault/sub, config.audit) enregistre
# chacune de ses ecritures.
#
# Dans le root, il ne peut que creer et lire les namespaces listes. Dans
# chacun : creer les mounts orgs/users (kv-v2), activer oidc/kubernetes, ecrire
# leurs configs et les roles `default` et `grant_*`, les policies `user_space`,
# `org_*`, `grant_*`, les groupes externes `org_*` et leurs alias. Aucun
# <mount>/data ni /metadata (pas un secret lisible), aucun delete de namespace,
# mount ou backend. Les memes lignes sont chargees telles quelles par
# `task test:live-openbao` de weebo-openbao contre un OpenBao 2.7.1.

locals {
  # Miroir de OpenbaoInstance.spec.bounds.namespaces (2.argo/helm/vault,
  # openbao.instance.namespaces). Ajouter un namespace passe par ici, une
  # fois : c'est un acte du root.
  spaces_namespaces = ["devenv", "recette", "preprod", "prod", "users"]
}

resource "vault_policy" "weebo_openbao_operator" {
  name = "weebo_openbao_operator"
  policy = join("\n", [for ns in local.spaces_namespaces : <<EOT
# Root : creer et lire ce namespace. OpenBao exige update (pas create) pour
# creer un namespace ou un mount, et update + sudo pour un backend d'auth.
path "sys/namespaces/${ns}" { capabilities = ["update", "read"] }

# Mounts : les seuls noms possibles sont les types.
path "${ns}/sys/mounts" { capabilities = ["read"] }
path "${ns}/sys/mounts/orgs" {
  capabilities       = ["update", "read"]
  allowed_parameters = { "type" = ["kv-v2"], "*" = [] }
}
path "${ns}/sys/mounts/users" {
  capabilities       = ["update", "read"]
  allowed_parameters = { "type" = ["kv-v2"], "*" = [] }
}

# Backends d'auth : oidc et kubernetes seulement. "+" et non "*" : le glob
# couvrirait <nom>/tune.
path "${ns}/sys/auth" { capabilities = ["read"] }
path "${ns}/sys/auth/+" {
  capabilities       = ["update", "read", "sudo"]
  allowed_parameters = { "type" = ["oidc", "kubernetes"], "*" = [] }
}
path "${ns}/auth/+/config" { capabilities = ["create", "read", "update"] }
path "${ns}/auth/+/role/default" {
  capabilities       = ["create", "read", "update"]
  allowed_parameters = { "*" = [], "token_policies" = ["user_space"] }
  denied_parameters  = { "policies" = [] }
}
path "${ns}/auth/+/role/grant_*" {
  capabilities       = ["create", "read", "update", "delete"]
  allowed_parameters = { "*" = [], "token_policies" = ["grant_*"] }
  denied_parameters  = { "policies" = [] }
}

# Policies : les trois familles que l'operateur rend. list : des noms
# seulement, pour nettoyer les objets marques sans CR.
path "${ns}/sys/policies/acl" { capabilities = ["list"] }
path "${ns}/identity/group/name" { capabilities = ["list"] }
path "${ns}/sys/policies/acl/user_space" { capabilities = ["create", "read", "update", "delete"] }
path "${ns}/sys/policies/acl/org_*" { capabilities = ["create", "read", "update", "delete"] }
path "${ns}/sys/policies/acl/grant_*" { capabilities = ["create", "read", "update", "delete"] }

# Groupes : externes, nommes org_*, ne portant que des policies org_*.
path "${ns}/identity/group/name/org_*" {
  capabilities       = ["create", "read", "update", "delete"]
  allowed_parameters = { "type" = ["external"], "policies" = ["org_*"], "metadata" = [] }
}

# Alias : par ID seulement.
path "${ns}/identity/group-alias" { capabilities = ["create", "update"] }
path "${ns}/identity/group-alias/id/*" { capabilities = ["read", "update", "delete"] }
EOT
  ])
}

# Le ServiceAccount du chart weebo-openbao (2.argo/helm/vault/main,
# templates/openbao), login Kubernetes dans le root : c'est
# OpenbaoInstance.spec.auth.kubernetes.
resource "vault_kubernetes_auth_backend_role" "weebo-openbao" {
  backend                          = data.vault_auth_backend.kubernetes.path
  role_name                        = "weebo-openbao"
  bound_service_account_names      = ["weebo-openbao"]
  bound_service_account_namespaces = ["weebo-openbao"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.weebo_openbao_operator.name]
}
