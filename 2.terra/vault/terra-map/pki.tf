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

# The rotation clock. Vault/OpenBao does NOT rotate issuers -- it issues leaves
# on demand and refuses (leaf_not_after_behavior = err, the default and what
# this mount has) to sign one that would outlive its issuer, but the issuer
# itself is a static object. Nothing renews it, and terraform on its own sees
# no diff as time passes, so the intermediate signed on 2026-06-26 would simply
# have lapsed on 2026-12-22.
#
# It fails earlier than it expires: the role caps leaves at max_ttl (30 days),
# so the last issuance that fits inside the issuer is one requested 30 days
# before it dies. Renewals would have started erroring around 2026-11-22, with
# ingresses breaking as each existing 30-day leaf ran out after that.
#
# This resource changes its own id every rotation_days, which is the diff that
# makes the two resources below get replaced -- a new key, a new CSR, a newly
# signed intermediate.
resource "time_rotating" "pki_intermediate" {
  rotation_days = 120
}

resource "vault_pki_secret_backend_intermediate_cert_request" "csr-request" {
  backend     = vault_mount.pki_int.path
  type        = "internal"
  common_name = "weebo.poc Intermediate Authority"
  key_bits    = 4096

  # Replaced with the signing below, so each rotation gets a fresh private key
  # rather than re-signing the old one. The previous key stays in the mount
  # attached to the previous issuer, which is what keeps already-issued leaves
  # verifiable.
  lifecycle {
    replace_triggered_by = [time_rotating.pki_intermediate]
  }
}

resource "vault_pki_secret_backend_root_sign_intermediate" "intermediate" {
  backend     = var.pki
  common_name = "weebo.poc Intermediate Authority"
  csr         = vault_pki_secret_backend_intermediate_cert_request.csr-request.csr
  format      = "pem_bundle"

  ttl        = 15480000
  issuer_ref = data.vault_pki_secret_backend_issuer.root_issuer.issuer_ref

  lifecycle {
    replace_triggered_by = [time_rotating.pki_intermediate]
  }
}

resource "vault_pki_secret_backend_intermediate_set_signed" "intermediate" {
  backend     = vault_mount.pki_int.path
  certificate = vault_pki_secret_backend_root_sign_intermediate.intermediate.certificate
}

# Without this, rotation is a silent no-op. Importing a signed intermediate
# ADDS an issuer to the mount; it does not touch which one is default. The
# mount was at default_follows_latest_issuer = false, so a freshly signed
# intermediate would have sat there unused while cert-manager kept issuing
# from the old, expiring one.
resource "vault_pki_secret_backend_config_issuers" "pki_int" {
  backend                       = vault_mount.pki_int.path
  default                       = vault_pki_secret_backend_intermediate_set_signed.intermediate.imported_issuers[0]
  default_follows_latest_issuer = true
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
  backend = vault_mount.pki_int.path
  # The literal "default", not a UUID resolved at apply time. Pinning the id of
  # whichever issuer happened to be default meant the role kept pointing at the
  # old intermediate after a rotation until the next apply re-read it; "default"
  # follows the mount, which config_issuers above keeps on the newest issuer.
  issuer_ref       = "default"
  depends_on       = [vault_pki_secret_backend_config_issuers.pki_int]
  name             = "weebo-poc"
  ttl              = 86400
  max_ttl          = 2592000
  allow_ip_sans    = true
  key_type         = "rsa"
  key_bits         = 4096
  allowed_domains  = ["weebo.poc"]
  allow_subdomains = true
}

resource "vault_kv_secret_v2" "certificate" {
  mount = "mv"
  name  = "cert-manager/config"
  data_json = jsonencode(
    {
      fullcert_chain = vault_pki_secret_backend_intermediate_set_signed.intermediate.certificate
    }
  )
}
