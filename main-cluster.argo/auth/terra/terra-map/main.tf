terraform {
  required_providers {
    authentik = {
      source  = "goauthentik/authentik"
      version = "2025.4.0"
    }
  }
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

provider "authentik" {
  url   = var.authentik_url
  token = var.authentik_token
}
