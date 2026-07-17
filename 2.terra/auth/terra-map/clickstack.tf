resource "authentik_provider_proxy" "clickstack" {
  name               = "clickstack"
  internal_host      = "http://clickstack-frontend.clickstack.svc.cluster.local"
  external_host      = "https://clickstack.weebo.poc"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "clickstack" {
  name              = "clickstack"
  slug              = "clickstack"
  protocol_provider = authentik_provider_proxy.clickstack.id
}

resource "authentik_outpost_provider_attachment" "clickstack" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.clickstack.id
}

resource "authentik_policy_binding" "clickstack-access" {
  target = authentik_application.clickstack.uuid
  group  = authentik_group.weebo_admin.id
  order  = 0
}
