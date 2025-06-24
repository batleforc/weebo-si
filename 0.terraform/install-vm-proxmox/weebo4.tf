variable "ovh_server_name" {
  type        = string
  description = "The name of the OVH dedicated server to use."
  default     = "nsxxxxxx.ip-xx-xxx-xxx.eu"
}

variable "ssh_public_key" {
  type        = string
  description = "The SSH public key to use for the server."
  default     = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC3v8z5Z9"
}


data "ovh_dedicated_server" "server" {
  service_name = var.ovh_server_name
}

data "ovh_dedicated_installation_template" "proxmox" {
  template_name = "proxmox8_64"
}

resource "ovh_dedicated_server_reinstall_task" "server_reinstall" {
  service_name = data.ovh_dedicated_server.server.service_name
  os           = data.ovh_dedicated_installation_template.proxmox.template_name
  customizations {
    hostname = "weebo4"
    ssh_key  = var.ssh_public_key
  }
  storage {
    partitioning {
      disks = 2
      layout {
        file_system = "ext4"
        mount_point = "/boot"
        raid_level  = 1
        size        = 1024
      }
      layout {
        file_system = "ext4"
        mount_point = "/"
        raid_level  = 1
        size        = 20480
      }
      layout {
        file_system = "swap"
        mount_point = "swap"
        size        = 2048
      }
      layout {
        file_system = "ext4"
        mount_point = "/var/lib/vz"
        raid_level  = 0
        size        = 870472
      }
    }
  }
}
