variable "pki" {
  type    = string
  default = "pki"
}

data "vault_pki_secret_backend_issuers" "pki_issuers" {
  backend = var.pki
}

data "vault_pki_secret_backend_issuer" "root_issuer" {
  backend    = var.pki
  issuer_ref = data.vault_pki_secret_backend_issuers.pki_issuers.key_info[0]
}
