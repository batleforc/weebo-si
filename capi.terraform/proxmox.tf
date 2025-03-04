resource "proxmox_virtual_environment_vm" "capi_template" {
  name        = "capi-master"
  description = "Capi Master"
  tags        = ["talos", "capi", "terraform", "weebo-si", "metal"]
  node_name   = var.proxmox_node_name
  vm_id       = "201"

  agent {
    enabled = true
  }

  clone {
    vm_id = "9999"
  }

  cpu {
    cores   = 1
    sockets = 2
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
    floating  = 2048
  }
  lifecycle {
    ignore_changes = [
      network_device
    ]
  }
}

locals {
  capi_possible_ip = [for ip in proxmox_virtual_environment_vm.capi_template.ipv4_addresses : ip if length(ip) != 0 && ip != tolist(["127.0.0.1"])]
}

output "capi_ip" {
  value = element(local.capi_possible_ip[0], 0)
}
