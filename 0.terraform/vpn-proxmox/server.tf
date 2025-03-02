resource "wireguard_asymmetric_key" "server" {
}

data "wireguard_config_document" "server" {
  private_key = wireguard_asymmetric_key.server.private_key
  listen_port = var.port
  mtu         = "1420"
  addresses   = ["192.168.100.0/20"]
  # Add ipv6 tables https://www.reddit.com/r/WireGuard/comments/178uolr/guide_how_to_set_up_wireguard_with_ipv6_in_docker/
  post_up = [
    "iptables -A FORWARD -i %i -j ACCEPT",
    "iptables -A FORWARD -o %i -j ACCEPT",
    "iptables -A FORWARD -i wg0 -o wg0 -j ACCEPT",
    "iptables -t nat -A POSTROUTING -o vmbr1 -j MASQUERADE",
    "ip6tables -A FORWARD -i %i -j ACCEPT",
    "ip6tables -A FORWARD -o %i -j ACCEPT",
    "ip6tables -A FORWARD -i wg0 -o wg0 -j ACCEPT",
    "ip6tables -t nat -A POSTROUTING -o vmbr1 -j MASQUERADE",
    "sysctl -w -q net.ipv4.ip_forward=1",
    "sysctl -w -q net.ipv6.conf.all.forwarding=1",
    "sysctl -w -q net.ipv6.conf.eth0.proxy_ndp=1"
  ]
  post_down = [
    "iptables -D FORWARD -i %i -j ACCEPT",
    "iptables -D FORWARD -o %i -j ACCEPT",
    "iptables -D FORWARD -i wg0 -o wg0 -j ACCEPT",
    "iptables -t nat -D POSTROUTING -o vmbr1 -j MASQUERADE",
    "ip6tables -D FORWARD -i %i -j ACCEPT",
    "ip6tables -D FORWARD -o %i -j ACCEPT",
    "ip6tables -D FORWARD -i wg0 -o wg0 -j ACCEPT",
    "ip6tables -t nat -D POSTROUTING -o vmbr1 -j MASQUERADE",
    "sysctl -w -q net.ipv4.ip_forward=0",
    "sysctl -w -q net.ipv6.conf.all.forwarding=0"
  ]

  # Note: This is the config for the client
  peer {
    public_key    = wireguard_asymmetric_key.pc1.public_key
    preshared_key = wireguard_preshared_key.pc1.key
    allowed_ips   = ["192.168.100.0/24"]
  }
}

resource "local_file" "server" {
  content  = data.wireguard_config_document.server.conf
  filename = "server.wg.conf"
}
