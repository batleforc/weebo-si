resource "vault_policy" "s3_policy" {
  name = "s3_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/{{identity.entity.aliases.${data.vault_auth_backend.kubernetes.accessor}.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
path "${vault_mount.main-vault.path}/data/+/s3" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "s3_policy" {
  role_name                        = "s3"
  bound_service_account_names      = ["default", "authentik-weebo-authentik"]
  bound_service_account_namespaces = ["s3"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.s3_policy.name]
}

resource "random_string" "batlehub-accessKey" {
  length  = 42
  special = false
}

resource "random_string" "batlehub-secretKey" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "batlehub-s3" {
  mount = "mv"
  name  = "batlehub/s3"
  data_json = jsonencode(
    {
      accesskey = random_string.batlehub-accessKey.result
      secretkey = random_string.batlehub-secretKey.result
    }
  )
}

resource "random_string" "angos-accessKey" {
  length  = 42
  special = false
}

resource "random_string" "angos-secretKey" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "angos-s3" {
  mount = "mv"
  name  = "angos/s3"
  data_json = jsonencode(
    {
      accesskey = random_string.angos-accessKey.result
      secretkey = random_string.angos-secretKey.result
    }
  )
}

resource "random_string" "main-accessKey" {
  length  = 42
  special = false
}

resource "random_string" "main-secretKey" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "main-s3" {
  mount = "mv"
  name  = "s3/s3"
  data_json = jsonencode(
    {
      accesskey = random_string.main-accessKey.result
      secretkey = random_string.main-secretKey.result
    }
  )
}