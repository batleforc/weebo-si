resource "netbird_network" "kamalos" {
  name        = "kamalos"
  description = "kamalos network"
}

## Kamalos internal cluster network resources

resource "netbird_group" "kamalos-peer" {
  name = "kamalos-peer"
}

resource "netbird_setup_key" "kamalos-peer" {
  name                   = "kamalos-peer"
  expiry_seconds         = 0 # 30 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.kamalos-peer.id]
  ephemeral              = true
  revoked                = false
  usage_limit            = 0
}

resource "vault_kv_secret_v2" "kamalos-peer" {
  mount = "mc-authentik"
  name  = "kamalos/vpn"
  data_json = jsonencode(
    {
      KUBERNETES_SETUP_KEY = netbird_setup_key.kamalos-peer.key
    }
  )
}

resource "netbird_network_resource" "kamalos-pod-cidr" {
  name        = "kamalos-pod-cidr"
  network_id  = netbird_network.kamalos.id
  groups      = [netbird_group.kamalos-peer.id]
  address     = "10.245.0.0/16"
  description = "Kamalos cluster pod's CIDR"
}

resource "netbird_network_resource" "kamalos-service-cidr" {
  name        = "kamalos-service-cidr"
  network_id  = netbird_network.kamalos.id
  groups      = [netbird_group.kamalos-peer.id]
  address     = "10.128.0.0/12"
  description = "Kamalos cluster service's CIDR"
}

## Kamalos setup cluster resources

resource "netbird_group" "kamalos-cp-access" {
  name = "kamalos-cp-access"

}

resource "netbird_setup_key" "kamalos-cp-access" {
  name                   = "kamalos-cp-access"
  expiry_seconds         = 0 # 30 days
  type                   = "reusable"
  allow_extra_dns_labels = true
  auto_groups            = [netbird_group.kamalos-cp-access.id]
  ephemeral              = true
  revoked                = false
  usage_limit            = 0
}

resource "vault_kv_secret_v2" "kamalos-cp-peer" {
  mount = "mc-authentik"
  name  = "kamalos/vpn-exit-node"
  data_json = jsonencode(
    {
      KUBERNETES_SETUP_KEY = netbird_setup_key.kamalos-peer.key
    }
  )
}

resource "netbird_network_resource" "kamalos-cp-pod-cidr" {
  name        = "kamalos-cp-pod-cidr"
  network_id  = netbird_network.kamalos.id
  groups      = [netbird_group.kamalos-cp-access.id]
  address     = "10.244.0.0/16"
  description = "Kamalos CP cluster pod's CIDR"
}

resource "netbird_network_resource" "kamalos-cp-service-cidr" {
  name        = "kamalos-cp-service-cidr"
  network_id  = netbird_network.kamalos.id
  groups      = [netbird_group.kamalos-cp-access.id]
  address     = "10.96.0.0/12"
  description = "Kamalos CP cluster service's CIDR"
}


# Group allocation to router
resource "netbird_network_router" "kamalos" {
  network_id = netbird_network.kamalos.id
  peer_groups = [
    netbird_group.kamalos-peer.id,
    netbird_group.kamalos-cp-access.id,
  ]
}

