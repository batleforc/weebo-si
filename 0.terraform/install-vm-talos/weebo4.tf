variable "ovh_server_name" {
  type        = string
  description = "The name of the OVH dedicated server to use."
  default     = "nsxxxxxx.ip-xx-xxx-xxx.eu"
}


data "ovh_dedicated_server" "server" {
  service_name = var.ovh_server_name
}

data "ovh_dedicated_installation_template" "proxmox" {
  template_name = "proxmox8_64"
}

resource "ovh_dedicated_server_reinstall_task" "server_reinstall" {
  service_name = data.ovh_dedicated_server.server.service_name
  os           = "byoi_64"
  customizations {
    hostname            = "weebo4"
    image_url           = "https://factory.talos.dev/image/b1ba84be4f5193a24085cc7e22fce31105e1583504d7d5aef494318f7cb1abd0/v1.10.4/metal-amd64.qcow2"
    efi_bootloader_path = "\\EFI\\BOOT\\BOOTX64.EFI"
    image_type          = "qcow2"

  }

  # storage {
  #   partitioning {
  #     disks = 2
  #     layout {
  #       file_system = "ext4"
  #       mount_point = "/boot"
  #       raid_level  = 0
  #       size        = 1024
  #     }
  #     layout {
  #       file_system = "ext4"
  #       mount_point = "/"
  #       raid_level  = 1
  #       size        = 913480
  #     }
  #   }
  # }
}
