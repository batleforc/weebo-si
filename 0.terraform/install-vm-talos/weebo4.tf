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
  os           = "byolinux_64"
  customizations {
    hostname  = "weebo4"
    image_url = data.talos_image_factory_urls.metal.urls.disk_image
  }
}
