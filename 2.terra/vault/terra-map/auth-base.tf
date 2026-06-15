resource "vault_mount" "main-vault" {
  path        = "mv"
  type        = "kv"
  options     = { version = "2" }
  description = "main vault"
}

resource "vault_kv_secret_backend_v2" "example" {
  mount = vault_mount.main-vault.path
}

resource "vault_policy" "mv_policy" {
  name = "mv_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}
path "sys/auth/*" { capabilities = ["create", "update", "delete", "sudo"] }
path "sys/auth" { capabilities = ["read", "list"] }
path "sys/policies/acl/*" { capabilities = ["create", "update", "delete", "sudo"] }
path "sys/policies/acl" { capabilities = ["read", "list"] }
path "auth/token/create" { capabilities = ["create", "read", "list"] }
path "auth/token/lookup-self" { capabilities = ["read", "list", "create"] }
path "auth/token/renew-self" { capabilities = ["update", "read"] }
path "sys/mounts" { capabilities = ["read","list"] }
path "sys/mounts/*" { capabilities = ["read","list"] }
path "sys/mounts/auth/*" { capabilities = ["read", "list", "update"] }
path "auth/*" { capabilities = ["read","list", "update", "create", "delete", "sudo"] }
path "identity/*" { capabilities = ["read","list", "update", "create", "delete", "sudo"] }
EOT
}

resource "vault_policy" "mv_reader_policy" {
  name = "mv_reader_policy"

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

resource "vault_kubernetes_auth_backend_role" "auth-write" {
  role_name                        = "auth"
  bound_service_account_names      = ["authentik", "default"]
  bound_service_account_namespaces = ["auth"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.mv_policy.name]
}

resource "vault_kubernetes_auth_backend_role" "auth-read" {
  role_name                        = "auth-read"
  bound_service_account_names      = ["authentik", "default", "vaultwarden-svc"]
  bound_service_account_namespaces = ["auth", "argocd", "vpn", "eclipse-che", "grafana", "registry", "exit-node-base", "monofolio", "guard", "chat", "dev-ws-max", "s3", "git-pages", "cert-manager", "ro"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.mv_reader_policy.name]
}
