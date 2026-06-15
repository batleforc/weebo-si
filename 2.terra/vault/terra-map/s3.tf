resource "random_password" "S3_ADMIN_PASSWORD" {
  length           = 42
  special          = true
  override_special = "_-"
}

resource "random_password" "S3_ADMIN_ID" {
  length           = 42
  special          = true
  override_special = "_-"
}

resource "vault_kv_secret_v2" "S3" {
  mount = vault_mount.main-vault.path
  name  = "s3/config"
  data_json = jsonencode(
    {
      S3_ADMIN_PASSWORD = random_password.S3_ADMIN_PASSWORD.result,
      S3_ADMIN_ID       = random_password.S3_ADMIN_ID.result,
    }
  )
}

resource "vault_policy" "mv_s3_admin_policy" {
  name = "mv_s3_admin_policy"

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
path "${vault_mount.main-vault.path}/data/+/s3" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "${vault_mount.main-vault.path}/metadata/+/s3" {
  capabilities = ["read","list"]
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

resource "vault_kubernetes_auth_backend_role" "s3_admin" {
  role_name                        = "s3-admin"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["s3"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.mv_s3_admin_policy.name]
}
