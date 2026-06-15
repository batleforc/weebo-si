resource "vault_policy" "monitoring" {
  name = "monitoring"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/config" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.main-vault.path}/data/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/sub" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/metadata/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/sub" {
  capabilities = ["read","list"]
}

path "${vault_mount.main-vault.path}/metadata/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/vpn" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/vpn" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.main-vault.path}/metadata/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/data/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.main-vault.path}/metadata/che-cluster/+/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/data/che-cluster/coroot/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "${vault_mount.main-vault.path}/metadata/+/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/data/+/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "${vault_mount.main-vault.path}/data/che-cluster/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-monitoring" {
  role_name                        = "monitoring"
  bound_service_account_names      = ["coroot","default"]
  bound_service_account_namespaces = ["coroot","monitoring"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.monitoring.name]
}
