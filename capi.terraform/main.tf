terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.78.1"
    }
    talos = {
      source  = "siderolabs/talos"
      version = "0.8.1"
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

variable "proxmox_ssh_username" {
  type    = string
  default = "root"
}

variable "proxmox_node_name" {
  type    = string
  default = "proxmox-node"
}

variable "talos_version" {
  type    = string
  default = "1.10.0"

}

provider "proxmox" {
  endpoint  = var.proxmox_api
  api_token = var.proxmox_api_token
}
