resource "random_string" "batlehub-valkey" {
  length  = 42
  special = false
}


resource "vault_kv_secret_v2" "batlehub-valkey" {
  mount = "mv"
  name  = "batlehub/config"
  data_json = jsonencode(
    {
      pwd = random_string.batlehub-valkey.result
      url = "redis://batlehub:${random_string.batlehub-valkey.result}@valkey-batlehub-valkey.batlehub.svc:6379"
    }
  )
}
