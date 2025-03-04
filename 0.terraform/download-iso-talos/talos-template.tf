resource "proxmox_virtual_environment_vm" "talos_template_metal" {
  name        = "talos-template-metal"
  description = "Talos template for metal"
  tags        = ["talos", "template", "terraform", "weebo-si", "metal"]
  node_name   = var.proxmox_node_name
  vm_id       = "9999"

  template = true

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
    file_id   = proxmox_virtual_environment_download_file.talos_metal.id
    interface = "ide2"
  }

  network_device {
    bridge = "vmbr1"
  }
}

resource "proxmox_virtual_environment_vm" "talos_template_nocloud" {
  name        = "talos-template-nocloud"
  description = "Talos template for nocloud"
  tags        = ["talos", "template", "terraform", "weebo-si", "nocloud"]
  node_name   = var.proxmox_node_name
  vm_id       = "9998"

  template = true

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
    file_id   = proxmox_virtual_environment_download_file.talos_nocloud.id
    interface = "ide2"
  }

  network_device {
    bridge = "vmbr1"
  }
}
