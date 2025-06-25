variable "ovh_server_name" {
  type        = string
  description = "The name of the OVH dedicated server to use."
  default     = "nsxxxxxx.ip-xx-xxx-xxx.eu"
}


data "ovh_dedicated_server" "server" {
  service_name = var.ovh_server_name
}

data "ovh_dedicated_server_specifications_network" "spec" {
  service_name = var.ovh_server_name
}

output "network" {
  value = {
    spec = data.ovh_dedicated_server_specifications_network.spec
    ipv4 = local.ipv4
    ipv6 = local.ipv6
  }
}

data "ovh_dedicated_installation_template" "proxmox" {
  template_name = "proxmox8_64"
}

resource "ovh_dedicated_server_reinstall_task" "server_reinstall" {
  service_name = data.ovh_dedicated_server.server.service_name
  os           = "byoi_64"
  customizations {
    hostname            = "weebo4"
    image_url           = "https://factory.talos.dev/image/${data.talos_image_factory_urls.metal.schematic_id}/${data.talos_image_factory_urls.metal.talos_version}/${data.talos_image_factory_urls.metal.platform}-amd64.qcow2"
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

locals {
  ipv4 = replace(data.ovh_dedicated_server_specifications_network.spec.routing.ipv4.ip, "/32", "")
  # Only keep the first IPV6 address in the .ips that end with /128
  ipv6 = one(toset([for ip in data.ovh_dedicated_server.server.ips : replace(ip, "/128", "") if can(regex("/128", ip))]))
}
