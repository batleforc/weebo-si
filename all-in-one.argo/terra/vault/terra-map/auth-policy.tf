resource "vault_policy" "authentik_policy" {
  name = "weebo_admin"

  policy = <<EOT
path "*" { capabilities = ["read","list", "update", "create", "delete", "sudo"] }
EOT
}
