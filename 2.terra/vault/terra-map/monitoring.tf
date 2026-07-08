resource "random_string" "monitoring-clickhouse-admin-password" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "monitoring-clickhouse" {
  mount = "mv"
  name  = "monitoring/config"
  data_json = jsonencode(
    {
      CLICKHOUSE_ADMIN_PASSWORD = random_string.monitoring-clickhouse-admin-password.result
    }
  )
}
