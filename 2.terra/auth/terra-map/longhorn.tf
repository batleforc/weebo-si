resource "authentik_provider_proxy" "longhorn" {
  name               = "longhorn"
  internal_host      = "http://longhorn-frontend.longhorn.svc.cluster.local"
  external_host      = "https://longhorn.weebo.poc"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
}

resource "authentik_application" "longhorn" {
  name              = "longhorn"
  slug              = "longhorn"
  protocol_provider = authentik_provider_proxy.longhorn.id
}

resource "authentik_outpost_provider_attachment" "longhorn" {
  outpost           = data.authentik_outpost.embedded.id
  protocol_provider = authentik_provider_proxy.longhorn.id
}

resource "authentik_policy_binding" "longhorn-access" {
  target = authentik_application.longhorn.uuid
  group  = authentik_group.weebo_admin.id
  order  = 0
}
