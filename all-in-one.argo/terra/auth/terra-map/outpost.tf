resource "authentik_outpost" "outpost" {
  name = "authentik Embedded Outpost"
  protocol_providers = [
    authentik_provider_proxy.kubevirt-manager.id
  ]
}
