terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "2.38.0"
    }
  }
}

variable "proxmox_api" {
  type    = string
  default = "truc.example.com"
}

variable "proxmox_api_token" {
  type    = string
  default = "trucTrucTruc"
}

variable "proxmox_secret" {
  type    = string
  default = "root"
}

provider "kubernetes" {
  config_path = "../capi.terraform/kubeconfig"
}
