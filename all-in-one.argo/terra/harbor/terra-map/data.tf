ephemeral "vault_kv_secret_v2" "harbor_config" {
  mount = "mc-authentik"
  name  = "harbor/config"
}

data "vault_kv_secret_v2" "harbor_auth" {
  mount = "mc-authentik"
  name  = "harbor/auth"
}