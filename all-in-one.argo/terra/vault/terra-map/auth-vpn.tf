resource "vault_policy" "authentik_vpn_policy" {
  name = "authentik_vpn_policy"

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
path "mc-authentik/metadata/+/vpn" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/+/vpn" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-vpn" {
  role_name                        = "auth-vpn"
  bound_service_account_names      = ["netbird", "default"]
  bound_service_account_namespaces = ["netbird"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_vpn_policy.name]
}