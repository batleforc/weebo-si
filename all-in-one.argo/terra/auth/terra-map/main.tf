terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.6.0"
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

variable "authentik_url" {
  type        = string
  description = "The URL of the Authentik instance"
  default     = "https://login.main-cluster.weebo.poc"
}

variable "authentik_token" {
  type        = string
  description = "The API token for Authentik"
  default     = "foo-bar"
}

variable "vault_addr" {
  type        = string
  description = "The address of the Vault instance"
  default     = "https://vault.capi.weebo.poc"
}

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}

provider "vault" {
  address          = var.vault_addr
  ca_cert_file     = "/etc/ssl/vault/ca.crt"
  skip_child_token = "true"
  auth_login_jwt {
    role  = "auth"
    jwt   = local.token_vault
    mount = "kubernetes"
  }
}
