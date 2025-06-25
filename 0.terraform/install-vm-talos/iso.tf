data "talos_image_factory_extensions_versions" "extensions_list" {
  # get the latest talos version
  talos_version = "v${var.talos_version}"
  filters = {
    names = [
      "iscsi-tools",
      "util-linux-tools",
      "intel-ucode"
    ]
  }
}

resource "talos_image_factory_schematic" "schematic_qemu" {
  schematic = yamlencode(
    {
      customization = {
        systemExtensions = {
          officialExtensions = data.talos_image_factory_extensions_versions.extensions_list.extensions_info.*.name
        },
        extraKernelArgs = [
          "net.ifnames=0"
        ]
      }
    }
  )
}


data "talos_image_factory_urls" "metal" {
  talos_version = data.talos_image_factory_extensions_versions.extensions_list.talos_version
  schematic_id  = talos_image_factory_schematic.schematic_qemu.id
  platform      = "metal"
}
