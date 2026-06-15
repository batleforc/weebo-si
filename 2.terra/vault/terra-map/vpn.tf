resource "vault_policy" "vpn_policy" {
  name = "vpn_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/config" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/sub" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/metadata/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/sub" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/metadata/+/vpn" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/+/vpn" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/metadata/+/vpn-exit-node" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/+/vpn-exit-node" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-vpn" {
  role_name                        = "vpn"
  bound_service_account_names      = ["vpn", "default"]
  bound_service_account_namespaces = ["vpn"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.vpn_policy.name]
}
