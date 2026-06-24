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
  issuer_ref = { for k, v in data.vault_pki_secret_backend_issuers.pki_issuers.key_info_json : k => v if v.is_default == true }
}

output "outtruc" {
  value = data.vault_pki_secret_backend_issuers.pki_issuers.key_info_json
}
