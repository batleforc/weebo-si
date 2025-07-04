resource "netbird_group" "kubernetes-peer" {
  name = "kubernetes-peer"
}

resource "netbird_setup_key" "kube-peer" {
  name                   = "Kubernetes Peer Setup Key"
  expiry_seconds         = 60 * 24 * 30 # 30 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.kubernetes-peer.id]
  ephemeral              = true
  revoked                = false
  usage_limit            = 0
}

resource "netbird_route" "kubernetes-peer" {
  network_id  = "kubernetes peer"
  groups      = [netbird_group.kubernetes-peer.id]
  peer_groups = [netbird_group.batleforc.id]
  description = "Kubernetes Peer Route"
  network     = "10.244.0.0/16" #,10.96.0.0/12,fd00:10:244::/56,fd00:10:96::/112"
}

resource "netbird_policy" "kubernetes-peer" {
  name    = "Kubernetes Peer Policy"
  enabled = true

  rule {
    action        = "accept"
    bidirectional = true
    enabled       = true
    protocol      = "all"
    name          = "Access Kubernetes Peer"
    sources       = [netbird_group.batleforc.id]
    destinations  = [netbird_group.kubernetes-peer.id]
  }
}


resource "vault_kv_secret_v2" "netbird" {
  mount = "mc-authentik"
  name  = "netbird/sub"
  data_json = jsonencode(
    {
      KUBERNETES_SETUP_KEY = netbird_setup_key.kube-peer.key
    }
  )
}
