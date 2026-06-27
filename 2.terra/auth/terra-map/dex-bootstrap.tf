resource "random_string" "kube-client-secret" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "dex" {
  mount = "mv"
  name  = "dex/auth"
  data_json = jsonencode(
    {
      KUBE_CLIENT_SECRET = random_string.kube-client-secret.result
    }
  )
}
