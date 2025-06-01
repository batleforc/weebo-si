resource "vault_mount" "main-cluster-authentik" {
  path        = "mc-authentik"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

resource "vault_kv_secret_backend_v2" "example" {
  mount = vault_mount.main-cluster-authentik.path
}

resource "vault_policy" "authentik_policy" {
  name = "authentik_policy"

  policy = <<EOT
path "mc-authentik/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOT
}

resource "vault_policy" "authentik_reader_policy" {
  name = "authentik_reader_policy"

  policy = <<EOT
path "mc-authentik/data/{{identity.entity.aliases.auth_kubernetes_5a5c946d.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
EOT
}

resource "random_string" "password" {
  length  = 16
  special = false
}

resource "random_string" "token" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.main-cluster-authentik.path
  name  = "main-config"
  data_json = jsonencode(
    {
      AUTHENTIK_BOOTSTRAP_PASSWORD = random_string.password.result,
      AUTHENTIK_BOOTSTRAP_TOKEN    = random_string.token.result,
      AUTHENTIK_BOOTSTRAP_EMAIL    = "admin@weebo.poc"
    }
  )
}

resource "vault_kubernetes_auth_backend_role" "auth-write" {
  backend                          = "main-cluster"
  role_name                        = "auth"
  bound_service_account_names      = ["authentik", "default"]
  bound_service_account_namespaces = ["authentik"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "auth-read" {
  backend                          = "main-cluster"
  role_name                        = "auth-read"
  bound_service_account_names      = ["authentik", "default"]
  bound_service_account_namespaces = ["authentik", "argocd-client"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_reader_policy.name]
}
