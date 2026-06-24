resource "vault_mount" "pki" {
  path = "pki"
  type = "pki"
}

data "vault_pki_secret_backend_issuers" "pki_issuers" {
  backend = vault_mount.pki.path
}

data "vault_pki_secret_backend_issuer" "root_issuer" {
  backend    = vault_mount.pki.path
  issuer_ref = data.vault_pki_secret_backend_issuers.pki_issuers.key_info[0]
}
