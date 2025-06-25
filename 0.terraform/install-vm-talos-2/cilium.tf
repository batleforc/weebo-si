resource "cilium" "example" {
  set = [
    "k8sServiceHost=${data.ovh_dedicated_server.server.ip}"
  ]
  values  = file("${path.module}/cilium-values.yaml")
  version = var.cilium_version
}
