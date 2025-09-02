resource "vault_policy" "authentik_reader_policy_che_cluster" {
  name = "authentik_reader_policy_che_cluster"

  policy = <<EOT
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/sub" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "mc-authentik/metadata/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/sub" {
  capabilities = ["read","list"]
}

path "mc-authentik/metadata/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/vpn" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/vpn" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_cd5c654a.metadata.service_account_namespace}}/monitoring" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-reader-che-cluster" {
  backend                          = "che-cluster"
  role_name                        = "auth-reader-che-cluster"
  bound_service_account_names      = ["che", "default","coroot"]
  bound_service_account_namespaces = ["eclipse-che","coroot"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_reader_policy_che_cluster.name]
}