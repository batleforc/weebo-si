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
  special = false
}

# Ingestion key handed to every telemetry producer (OBI, collectors, SDKs).
# A UUID rather than a random_string because it travels inside
# OTEL_EXPORTER_OTLP_HEADERS ("authorization=<key>"), whose key=value,key=value
# grammar breaks on the "=" and "," that random_string's special set contains.
# It is also the shape HyperDX generates natively (uuidv4 in models/team.ts).
resource "random_uuid" "monitoring-otel-ingestion-key" {}

# Must satisfy HyperDX's passwordSchema: 12-72 chars with at least one upper,
# lower, digit and a special char from !@#$%^&*(),.?":{}|<>;-+= — the set is
# narrowed here to the shell-safe subset since the bootstrap Job passes this
# through curl.
resource "random_password" "monitoring-hyperdx-admin-password" {
  length           = 24
  min_upper        = 2
  min_lower        = 2
  min_numeric      = 2
  min_special      = 2
  override_special = "!@#%^*.?-+"
}

# Kept in its own KV path, apart from monitoring/config: the cluster-wide
# otel_ingest_reader_policy grants read on this path from any namespace, so it
# must never hold the ClickHouse/Mongo passwords.
resource "vault_kv_secret_v2" "monitoring-otel" {
  mount = "mv"
  name  = "monitoring/otel"
  data_json = jsonencode(
    {
      INGESTION_API_KEY = random_uuid.monitoring-otel-ingestion-key.result
    }
  )
}

# Consumed only by the clickstack-bootstrap Job, which registers the first
# HyperDX user so no one ever has to open the signup form by hand.
resource "vault_kv_secret_v2" "monitoring-hyperdx" {
  mount = "mv"
  name  = "monitoring/hyperdx"
  data_json = jsonencode(
    {
      ADMIN_EMAIL    = "admin@batleforc.fr"
      ADMIN_PASSWORD = random_password.monitoring-hyperdx-admin-password.result
    }
  )
  lifecycle {
    ignore_changes = [data_json]
  }
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
  lifecycle {
    ignore_changes = [data_json]
  }
}
