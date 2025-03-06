
resource "kubernetes_namespace" "capi" {
  metadata {
    name = "cluster-api"
  }
}

resource "kubernetes_secret" "infra_provider" {
  metadata {
    name      = "infra-provider"
    namespace = kubernetes_namespace.capi.metadata.0.name
  }

  data = {
    PROXMOX_URL    = var.proxmox_api
    PROXMOX_TOKEN  = var.proxmox_api_token
    PROXMOX_SECRET = var.proxmox_secret
  }
}
