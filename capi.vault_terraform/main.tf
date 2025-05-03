terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "4.8.0"
    }
  }
}

variable "vault_token" {
  description = "The token to authenticate with Vault"
  type        = string
}

provider "vault" {
  address = "https://vault.capi.weebo.poc"
  token   = var.vault_token
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
  issuer_ref  = "098bc894-b1b1-55f0-3879-bb09b1a4ee1f"
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = "pki_int"
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}
