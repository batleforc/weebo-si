resource "wireguard_asymmetric_key" "pc1" {
}
resource "wireguard_preshared_key" "pc1" {
}

data "wireguard_config_document" "pc1" {
  private_key = wireguard_asymmetric_key.pc1.private_key
  mtu         = "1280"
  addresses   = ["192.168.101.10/20"]

  # Serveur
  peer {
    public_key           = wireguard_asymmetric_key.server.public_key
    preshared_key        = wireguard_preshared_key.pc1.key
    allowed_ips          = ["192.168.100.0/24", "192.168.101.0/20", "10.244.0.0/16", "10.96.0.0/12"]
    endpoint             = "${var.dns}:${var.port}"
    persistent_keepalive = 25
  }
}

resource "local_file" "pc1" {
  content  = data.wireguard_config_document.pc1.conf
  filename = "pc1.wg.conf"
}
