resource "cilium" "install" {
  set = [
    "k8sServiceHost=${data.ovh_dedicated_server.server.ip}"
  ]
  values  = file("${path.module}/cilium-values.yaml")
  version = var.cilium_version
}

resource "cilium_hubble" "hubble" {
  ui = true
}

# resource "kubernetes_manifest" "ip-pool" {
#   depends_on = [cilium.install]
#   manifest = {
#     "apiVersion" = "cilium.io/v2alpha1"
#     "kind"       = "CiliumLoadBalancerIPPool"
#     "metadata" = {
#       "name" = "ip-pool"
#     }
#     "spec" = {
#       "blocks" = [
#         {
#           "start" = data.ovh_dedicated_server.server.ip
#           "stop"  = data.ovh_dedicated_server.server.ip
#         }
#       ]
#     }
#   }
# }


