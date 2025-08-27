resource "netbird_group" "batleforc" {
  name = "batleforc"
  peers = [
    data.netbird_peer.phone.id,
    data.netbird_peer.pc.id,
  ]
}

data "netbird_peer" "phone" {
  ip = "100.113.51.239"
}

data "netbird_peer" "pc" {
  ip = "100.113.58.229"
}
