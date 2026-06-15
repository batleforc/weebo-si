terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.8.0"
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
  address      = "https://vault.vault:8200"
  ca_cert_file = "/etc/ssl/vault/ca.crt"
  token        = local.token_vault
}
