resource "vault_policy" "authentik_policy" {
  name = "weebo_admin"

  policy = <<EOT
path "mc-authentik/*" {
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
path "auth/*" { capabilities = ["read","list", "update", "create", "delete", "sudo"] }
path "identity/*" { capabilities = ["read","list", "update", "create", "delete", "sudo"] }
EOT
}
