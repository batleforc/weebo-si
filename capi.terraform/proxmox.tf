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

  disk {
    datastore_id = "local"
    interface    = "scsi0"
    replicate    = false
    backup       = false
    aio          = null
    size         = 50
  }

  memory {
    dedicated = 12288
    floating  = 12288
  }
  lifecycle {
    ignore_changes = [
      network_device
    ]
  }
}

locals {
  capi_possible_ip = [for ip in [for ip in proxmox_virtual_environment_vm.capi_template.ipv4_addresses : ip if length(ip) > 0] : ip if ip != tolist(["127.0.0.1"]) && ip != ["127.0.0.1"] && startswith(ip[0], "192.168.")]
}

