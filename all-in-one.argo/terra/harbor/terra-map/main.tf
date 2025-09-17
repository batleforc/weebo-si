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

provider "harbor" {
  url      = "https://harbor.4.weebo.fr"
  username = var.username
  password = var.password
}