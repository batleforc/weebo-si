resource "vault_policy" "registry_policy" {
  name = "registry_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/+/+/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/+/+/+/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.git_vault.path}/+/+/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.git_vault.path}/+/+/+/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.main-vault.path}/metadata/registry/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/data/registry/registry" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
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
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-registry" {
  role_name                        = "registry"
  bound_service_account_names      = ["registry", "default"]
  bound_service_account_namespaces = ["registry"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.registry_policy.name]
}
