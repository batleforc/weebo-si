variable "ovh_server_name" {
  type        = string
  description = "The name of the OVH dedicated server to use."
  default     = "nsxxxxxx.ip-xx-xxx-xxx.eu"
}


data "ovh_dedicated_server" "server" {
  service_name = var.ovh_server_name
}

resource "ovh_dedicated_server_reboot_task" "server_reboot" {
  service_name = data.ovh_dedicated_server.server.service_name

  keepers = [
    data.ovh_dedicated_server.server.service_name
  ]
}

output "truc" {
  value = data.ovh_dedicated_server.server.service_name
}
