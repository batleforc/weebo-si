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

# Encrypts the oauth2-proxy session cookie, which is where the browser's ID
# token lives between requests. oauth2-proxy takes 16, 24 or 32 bytes: it first
# tries to base64-decode this value and falls back to the raw string, so 32
# alphanumeric characters are accepted either way. Rotating it logs every
# browser out; no registry token or OIDC token is affected.
resource "random_string" "angos-oauth2-cookie" {
  length  = 32
  special = false
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
      # Read by the oauth2-proxy that fronts the web UI (2.argo/helm/angos).
      # Kept here rather than in `angos/auth` because that path is written by
      # the Authentik operator's `secretTargets` and would drop any key it does
      # not own.
      oauth2_cookie_secret = random_string.angos-oauth2-cookie.result
    }
  )
}