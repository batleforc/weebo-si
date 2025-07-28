resource "netbird_nameserver_group" "main-test" {
  name        = "Test Nameserver Group"
  description = "Test Nameserver Group for Netbird"
  nameservers = [
    {
      ip      = "10.96.0.10"
      ns_type = "udp"
      port    = 53
    }
  ]
  groups                 = [netbird_group.batleforc.id]
  search_domains_enabled = false
}
