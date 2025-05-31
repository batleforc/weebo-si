data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

resource "authentik_provider_oauth2" "argo-main-cluster" {
  name               = "main-cluster.argo"
  client_id          = "main-cluster.argo"
  invalidation_flow  = "default-provider-invalidation-flow"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://main-cluster.argo.weebo.poc/oauth2/callback",
    },
  ]
}

resource "authentik_application" "argo-main-cluster" {
  name              = "main-cluster.argo"
  slug              = "main-cluster.argo"
  protocol_provider = authentik_provider_oauth2.argo-main-cluster.id
}
