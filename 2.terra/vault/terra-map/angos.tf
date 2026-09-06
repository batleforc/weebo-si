resource "random_string" "angos-valkey" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "angos-valkey" {
  mount = "mv"
  name  = "angos/config"
  data_json = jsonencode(
    {
      pwd = random_string.angos-accessKey.result
      url = "redis://angos:${random_string.angos-accessKey.result}@valkey.angos.svc:6379"
    }
  )
}