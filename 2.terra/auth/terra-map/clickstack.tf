resource "authentik_provider_proxy" "clickstack" {
  name               = "clickstack"
  # preauth-proxy, not HyperDX itself: the IngressRoute has pointed at the proxy
  # since clickstack.preauth.enabled, and HyperDX is only reachable behind it.
  # Unused in the forward-auth path this application actually takes -- the
  # `authentik` middleware calls /outpost.goauthentik.io/auth/traefik and
  # Traefik does the proxying -- but it is the record of what this provider
  # fronts, so it follows the route.
  internal_host      = "http://clickstack-preauth.monitoring.svc.cluster.local:8080"
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
