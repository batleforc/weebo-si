resource "netbird_network" "che-cluster" {
  name        = "che-cluster"
  description = "che-cluster network"
}

resource "netbird_group" "che-cluster-peer" {
  name = "che-cluster-peer"
}

resource "netbird_setup_key" "che-cluster-peer" {
  name                   = "che-cluster-peer"
  expiry_seconds         = 0 # 30 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.che-cluster-peer.id]
  ephemeral              = true
  revoked                = false
  usage_limit            = 0
}

resource "vault_kv_secret_v2" "che-cluster-peer" {
  mount = "mc-authentik"
  name  = "che/vpn"
  data_json = jsonencode(
    {
      KUBERNETES_SETUP_KEY = netbird_setup_key.che-cluster-peer.key
    }
  )
}

resource "netbird_network_resource" "che-cluster-pod-cidr" {
  name        = "che-cluster-pod-cidr"
  network_id  = netbird_network.che-cluster.id
  groups      = [netbird_group.che-cluster-peer.id]
  address     = "10.245.0.0/16"
  description = "Che cluster pod's CIDR"
}

resource "netbird_network_resource" "che-cluster-service-cidr" {
  name        = "che-cluster-service-cidr"
  network_id  = netbird_network.che-cluster.id
  groups      = [netbird_group.che-cluster-peer.id]
  address     = "10.112.0.0/12"
  description = "Che cluster service's CIDR"
}

resource "netbird_network_resource" "che-cluster-fqdn" {
  name        = "che-cluster-fqdn"
  network_id  = netbird_network.che-cluster.id
  groups      = [netbird_group.che-cluster-peer.id]
  address     = "*.che.cluster.4.weebo.fr"
  description = "Che cluster FQDN's CIDR"
}

resource "netbird_group" "che_admin" {
  name = "che_admin"
  peers = []
}

resource "netbird_group" "che_ops" {
  name = "che_ops"
  peers = []
}

resource "netbird_group" "che_dev" {
  name = "che_dev"
  peers = []
}

resource "netbird_network_router" "che-cluster" {
  network_id = netbird_network.che-cluster.id
  peer_groups = [
    netbird_group.che-cluster-peer.id,
    netbird_group.che_admin.id,
    netbird_group.che_ops.id,
    netbird_group.che_dev.id
  ]
}