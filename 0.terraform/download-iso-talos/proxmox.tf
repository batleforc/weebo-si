resource "proxmox_virtual_environment_download_file" "talos_metal" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node_name
  url          = data.talos_image_factory_urls.metal.urls.iso
  file_name    = "talos-v${var.talos_version}-metal.iso"
}

resource "proxmox_virtual_environment_download_file" "talos_nocloud" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = var.proxmox_node_name
  url          = data.talos_image_factory_urls.nocloud.urls.iso
  file_name    = "talos-v${var.talos_version}-nocloud.iso"
}
