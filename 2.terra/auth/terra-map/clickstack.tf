resource "authentik_provider_proxy" "clickstack" {
  name = "clickstack"
  # The mode the `authentik` Traefik middleware actually implements, and NOT the
  # provider default (`proxy`), which is what every other provider in this
  # directory still runs on.
  #
  # In `proxy` mode the outpost does not merely answer "authorised" -- it
  # *proxies the request itself* to internal_host and returns that response to
  # Traefik. But the URL it proxies is its own endpoint,
  # /outpost.goauthentik.io/auth/traefik, so the upstream is asked for a path it
  # has never heard of. Whatever comes back is then returned as the answer to
  # the browser's *original* request, whatever that was.
  #
  # That is invisible behind an SPA on nginx -- longhorn's `try_files` answers
  # 200 with index.html for the unknown path, Traefik reads the 200 as "allowed"
  # and forwards the real request. HyperDX is Next.js: it answers 404 for the
  # unknown path, so authentik handed Traefik a 404 and its "This page could not
  # be found" body, which Traefik then served for the document, every JS chunk,
  # every font and every /api call alike. Authentication had already succeeded
  # (the outpost logs `user: batleforc` on those very 404s) -- nothing was
  # denied, the answer was simply the wrong upstream's error page.
  #
  # `forward_single` makes the outpost do the one thing a forward-auth gateway
  # is asked to do: return 200 with the identity headers and let Traefik route.
  # It also fixes the post-login landing at the source, since the outpost then
  # builds `rd` from X-Forwarded-Uri (the page the caller asked for) instead of
  # from its own endpoint -- see the authentik-auth-landing middleware, which
  # this makes a safety net rather than the load-bearing workaround it was.
  mode = "forward_single"
  # No internal_host: in forward-auth the outpost never proxies anything, so
  # there is no internal host for it to hold. It was pointing at HyperDX, which
  # is precisely what made the proxy-mode behaviour above possible.
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
