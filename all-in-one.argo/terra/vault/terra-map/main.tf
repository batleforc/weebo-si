terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.0.0"
    }
  }
}

locals {
  token_vault = file("/var/run/vault/vault-root")
}


provider "vault" {
  address      = "https://vault.vault:8200"
  ca_cert_file = "/etc/ssl/vault/ca.crt"
  token        = local.token_vault
}

resource "vault_pki_secret_backend_intermediate_cert_request" "csr-request" {
  backend     = "pki_int"
  type        = "internal"
  common_name = "weebo.poc Intermediate Authority"
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend     = "pki"
  common_name = "weebo.poc Intermediate CA"
  csr         = vault_pki_secret_backend_intermediate_cert_request.csr-request.csr
  format      = "pem_bundle"
  ttl         = 15480000
  issuer_ref  = "7ba978da-bc38-337a-cc03-d6c6279abf62"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = "pki_int"
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}
