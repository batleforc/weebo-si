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

output "name" {
  value = data.ovh_dedicated_server_specifications_network.spec
}
