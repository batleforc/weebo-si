resource "authentik_provider_proxy" "glance" {
  name               = "glance"
  internal_host      = "http://glance.glance.svc.cluster.local:8080"
  external_host      = "https://glance.4.weebo.fr"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "glance" {
  name              = "glance"
  slug              = "glance"
  protocol_provider = authentik_provider_proxy.glance.id
}
