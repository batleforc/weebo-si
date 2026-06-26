# https://developer.hashicorp.com/vault/tutorials/pki/pki-engine?productSlug=vault&tutorialSlug=secrets-management&tutorialSlug=pki-engine
variable "pki" {
  type    = string
  default = "pki"
}

data "vault_pki_secret_backend_issuers" "pki_issuers" {
  backend = var.pki
}

data "vault_pki_secret_backend_issuer" "root_issuer" {
  backend = var.pki
  # Get the one who is default
  issuer_ref = keys({ for k, v in data.vault_pki_secret_backend_issuers.pki_issuers.key_info : k => k if jsondecode(v).is_default == true })[0]
}

resource "vault_mount" "pki_int" {
  path        = "pki_int"
  type        = "pki"
  description = "Intermediary pki cert"

  default_lease_ttl_seconds = 86400
  max_lease_ttl_seconds     = 157680000
}

resource "vault_pki_secret_backend_intermediate_cert_request" "csr-request" {
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "weebo.poc Intermediate Authority"
  key_bits    = 4096
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend     = var.pki
  common_name = "weebo.poc Intermediate Authority"
  csr         = vault_pki_secret_backend_intermediate_cert_request.csr-request.csr
  format      = "pem_bundle"
  ttl         = 15480000
  issuer_ref  = data.vault_pki_secret_backend_issuer.root_issuer.issuer_ref
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}

data "vault_pki_secret_backend_issuers" "pki_intermediate_issuers" {
  backend = vault_mount.pki_int.path
}

data "vault_pki_secret_backend_issuer" "intermediate" {
  depends_on = [
    vault_pki_secret_backend_intermediate_set_signed.intermediate,
    data.vault_pki_secret_backend_issuers.pki_intermediate_issuers
  ]
  backend = vault_mount.pki_int.path
  # Get the one who is default
  issuer_ref = keys({ for k, v in data.vault_pki_secret_backend_issuers.pki_intermediate_issuers.key_info : k => k if jsondecode(v).is_default == true })[0]
}

resource "vault_pki_secret_backend_role" "intermediate_role" {
  backend          = vault_mount.pki_int.path
  issuer_ref       = data.vault_pki_secret_backend_issuer.intermediate.issuer_ref
  name             = "weebo-poc"
  ttl              = 86400
  max_ttl          = 2592000
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["weebo.poc"]
  allow_subdomains = true
}
