terraform {
  required_providers {
    netbird = {
      source = "registry.terraform.io/netbirdio/netbird"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "5.0.0"
    }
  }
}

locals {
  token_vault = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}

variable "netbird_token" {
  sensitive   = true
  description = "NetBird Management Access Token"
}

variable "netbird_management_url" {
  description = "NetBird Management URL"
  default     = "https://netbird.4.weebo.fr:443"
}

provider "vault" {
  address          = "https://vault.vault:8200"
  ca_cert_file     = "/etc/ssl/vault/ca.crt"
  skip_child_token = "true"
  auth_login_jwt {
    role  = "auth"
    jwt   = local.token_vault
    mount = "kubernetes"
  }
}



provider "netbird" {
  token          = var.netbird_token
  management_url = var.netbird_management_url
}


resource "netbird_account_settings" "example" {
  jwt_allow_groups           = []
  jwt_groups_claim_name      = "groups"
  groups_propagation_enabled = true
  jwt_groups_enabled         = true
}
