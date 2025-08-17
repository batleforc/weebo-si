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
EOT
}

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
EOT
}

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

resource "random_string" "password" {
  length  = 16
  special = false
}

resource "random_string" "token" {
  length  = 42
  special = true
}

resource "random_string" "secret_key" {
  length  = 24
  special = true
}

resource "random_string" "postgres_password" {
  length  = 42
  special = true
}

resource "random_string" "postgres_password_user" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "example" {
  mount = vault_mount.main-cluster-authentik.path
  name  = "main-config"
  data_json = jsonencode(
    {
      AUTHENTIK_BOOTSTRAP_PASSWORD     = random_string.password.result,
      AUTHENTIK_BOOTSTRAP_TOKEN        = random_string.token.result,
      AUTHENTIK_BOOTSTRAP_EMAIL        = "admin@weebo.poc"
      AUTHENTIK_SECRET_KEY             = random_string.secret_key.result,
      AUTHENTIK_POSTGRES_PASSWORD      = random_string.postgres_password.result,
      AUTHENTIK_POSTGRES_USER_PASSWORD = random_string.postgres_password_user.result,
    }
  )
}

resource "vault_kubernetes_auth_backend_role" "auth-write" {
  role_name                        = "auth"
  bound_service_account_names      = ["authentik", "default"]
  bound_service_account_namespaces = ["authentik"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "auth-read" {
  role_name                        = "auth-read"
  bound_service_account_names      = ["authentik", "default", "kubevirt-omni"]
  bound_service_account_namespaces = ["authentik", "argocd", "netbird", "kubevirt-omni", "che"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_reader_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "auth-vpn" {
  role_name                        = "auth-vpn"
  bound_service_account_names      = ["netbird", "default"]
  bound_service_account_namespaces = ["netbird"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_vpn_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "auth-reader-che-cluster" {
  backend                          = "che-cluster"
  role_name                        = "auth-reader-che-cluster"
  bound_service_account_names      = ["che", "default"]
  bound_service_account_namespaces = ["eclipse-che"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_reader_policy_che_cluster.name]
}
