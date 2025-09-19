terraform {
  required_providers {
    harbor = {
      source = "goharbor/harbor"
    }
    vault = {
      source  = "hashicorp/vault"
    }
  }
}

locals {
  token_vault = file("/var/run/secrets/kubernetes.io/serviceaccount/token")
}

variable "vault_addr" {
  type        = string
  description = "The address of the Vault instance"
  default     = "https://vault.capi.weebo.poc"
}

variable "username" {
  type    = string
  default = "admin"
}

provider "vault" {
  address          = var.vault_addr
  ca_cert_file     = "/etc/ssl/vault/ca.crt"
  skip_child_token = "true"
  auth_login_jwt {
    role  = "auth-harbor"
    jwt   = local.token_vault
    mount = "kubernetes"
  }
}

provider "harbor" {
  url      = "https://harbor.4.weebo.fr"
  username = var.username
  password = data.vault_kv_secret_v2.harbor_config.data.HARBOR_ADMIN_PASSWORD
}