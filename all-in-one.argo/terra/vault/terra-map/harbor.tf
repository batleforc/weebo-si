resource "random_password" "HARBOR_ADMIN_PASSWORD" {
  length           = 42
  special          = true
  override_special = "_-"
}

resource "vault_kv_secret_v2" "harbor" {
  mount = "mc-authentik"
  name  = "harbor/config"
  data_json = jsonencode(
    {
      HARBOR_ADMIN_PASSWORD     = random_password.HARBOR_ADMIN_PASSWORD.result,
    }
  )
}
