resource "authentik_provider_proxy" "kubevirt-manager" {
  name               = "kubevirt-manager"
  internal_host      = "http://kubevirt-manager.kubevirt-manager.svc.cluster.local:8080"
  external_host      = "https://kubevirt-manager.4.weebo.fr"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
}

resource "authentik_application" "kubevirt-manager" {
  name              = "kubevirt-manager"
  slug              = "kubevirt-manager"
  protocol_provider = authentik_provider_proxy.kubevirt-manager.id
}
