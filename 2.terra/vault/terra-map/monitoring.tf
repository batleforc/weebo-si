resource "random_string" "monitoring-clickhouse-admin-password" {
  length  = 42
  special = true
}

resource "random_string" "monitoring-hyperdx-api-key" {
  length  = 42
  special = true
}

resource "random_string" "monitoring-clickhouse-app-password" {
  length  = 42
  special = true
}

resource "random_string" "monitoring-clickhouse-otel-password" {
  length  = 42
  special = true
}

resource "random_string" "monitoring-mongodb-password" {
  length  = 42
  special = true
}

resource "vault_kv_secret_v2" "monitoring-clickhouse" {
  mount = "mv"
  name  = "monitoring/config"
  data_json = jsonencode(
    {
      CLICKHOUSE_ADMIN_PASSWORD = random_string.monitoring-clickhouse-admin-password.result
      HYPERDX_API_KEY           = random_string.monitoring-hyperdx-api-key.result
      CLICKHOUSE_APP_PASSWORD   = random_string.monitoring-clickhouse-app-password.result
      CLICKHOUSE_OTEL_PASSWORD  = random_string.monitoring-clickhouse-otel-password.result
      MONGODB_PASSWORD          = random_string.monitoring-mongodb-password.result
    }
  )
}
