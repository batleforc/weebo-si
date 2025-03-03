resource "proxmox_virtual_environment_vm" "talos_template" {
  name        = "talos-template"
  description = "Talos template"
  tags        = ["talos", "template", "terraform", "weebo-si"]
  node_name   = var.proxmox_node_name
  vm_id       = "9999"

  agent {
    enabled = true
  }

  cpu {
    cores   = 1
    sockets = 1
    type    = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
    floating  = 2048
  }

  disk {
    datastore_id = "local"
    interface    = "scsi0"
    replicate    = false
    backup       = false
    aio          = null
  }

  cdrom {
    file_id   = "local:iso/talos-v${var.talos_version}.iso"
    interface = "ide2"
  }

  network_device {
    bridge = "vmbr1"
  }


}
