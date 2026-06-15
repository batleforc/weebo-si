resource "vault_policy" "tsig_push_policy" {
  name = "tsig_push_policy"

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
path "${vault_mount.main-vault.path}/data/cert-manager/tsig" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/metadata/cert-manager/tsig" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/monitoring" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/metadata/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/monitoring" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/vpn-exit-node" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/metadata/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/vpn-exit-node" {
  capabilities = ["read","list"]
}

EOT
}

resource "vault_kubernetes_auth_backend_role" "tsig_push" {
  role_name                        = "tsig-push"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["dns"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.tsig_push_policy.name]
}
