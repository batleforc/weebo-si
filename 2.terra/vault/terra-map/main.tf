terraform {
  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "5.11.0"
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
