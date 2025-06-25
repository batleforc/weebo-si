terraform {
  required_providers {
    ovh = {
      source = "ovh/ovh"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
    }
  }
}

variable "talos_version" {
  type    = string
  default = "1.10.4"
}

variable "fqdn" {
  type    = string
  default = "talos.local"
}


provider "ovh" {}
