resource "vault_mount" "git_vault" {
  path        = "git-vault"
  type        = "kv"
  options     = { version = "2" }
  description = "Vault for Git repositories secrets"
}

resource "vault_policy" "forgejo_policy" {
  name = "forgejo_policy"

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

path "${vault_mount.main-vault.path}/data/forgejo-action/sub" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/metadata/forgejo-action/sub" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "forgejo_policy" {
  role_name                        = "forgejo-readwrite"
  bound_service_account_names      = ["default", "forgejo-runner"]
  bound_service_account_namespaces = ["git", "forgejo-action"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.forgejo_policy.name]
}
