resource "random_string" "angos-valkey" {
  length  = 42
  special = false
}

# `random_id` rather than the `random_string` above: angos wants a base64 HMAC
# key and validates that it decodes to at least 32 bytes, which a 42-character
# alphanumeric string does not survive.
resource "random_id" "angos-token-service" {
  byte_length = 32
}

resource "vault_kv_secret_v2" "angos-valkey" {
  mount = "mv"
  name  = "angos/config"
  data_json = jsonencode(
    {
      pwd = random_string.angos-accessKey.result
      url = "redis://angos:${random_string.angos-accessKey.result}@valkey-angos-valkey.angos.svc:6379"
      # Signs the bearer tokens `GET /token` hands out. Rotating it invalidates
      # every registry token already issued; the OIDC ones are untouched.
      token_service_key = random_id.angos-token-service.b64_std
    }
  )
}