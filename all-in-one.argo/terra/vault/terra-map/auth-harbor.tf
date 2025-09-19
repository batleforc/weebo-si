resource "vault_policy" "authentik_harbor_policy" {
  name = "authentik_harbor_policy"

  policy = <<EOT
path "mc-authentik/data/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "mc-authentik/data/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/sub" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "mc-authentik/metadata/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/sub" {
  capabilities = ["read","list"]
}
path "mc-authentik/+/+/harbor" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/+/+/+/harbor" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/+/harbor/harbor" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-harbor" {
  role_name                        = "auth-harbor"
  bound_service_account_names      = ["harbor", "default"]
  bound_service_account_namespaces = ["harbor"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_harbor_policy.name]
}