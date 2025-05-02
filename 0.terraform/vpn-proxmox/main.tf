terraform {
  required_providers {
    wireguard = {
      source  = "OJFord/wireguard"
      version = "0.3.2"
    }
  }
}

variable "dns" {
  type    = string
  default = "truc.example.com"
}

variable "port" {
  type    = number
  default = "41820"
}

provider "wireguard" {

}
