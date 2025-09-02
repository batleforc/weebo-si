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