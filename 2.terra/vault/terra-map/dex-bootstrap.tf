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

resource "random_string" "zitadel-master-key" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "zitadel-master-key" {
  mount = "mv"
  name  = "zitadel/config"
  data_json = jsonencode(
    {
      masterkey = random_string.zitadel-master-key.result
    }
  )
}
