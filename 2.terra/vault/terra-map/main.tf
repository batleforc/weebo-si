terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.8.0"
    }
    # Drives the PKI intermediate rotation clock in pki.tf. Vault does not
    # rotate issuers on its own -- it only refuses to issue leaves that would
    # outlive one -- so the schedule has to come from somewhere, and this is
    # the piece that gives terraform a reason to re-sign.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.13"
    }
  }
}

locals {
  token_vault = file("/var/run/vault/vault-root")
}

data "vault_auth_backend" "kubernetes" {
  path = "kubernetes"
}


provider "vault" {
  address      = "https://openbao.vault:8200"
  ca_cert_file = "/etc/ssl/vault/ca.crt"
  token        = local.token_vault
}
