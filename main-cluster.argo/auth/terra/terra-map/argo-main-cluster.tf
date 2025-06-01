data "authentik_flow" "default-authorization-flow" {
  slug = "default-provider-authorization-implicit-consent"
}

data "authentik_flow" "default-invalidation-flow" {
  slug = "default-provider-invalidation-flow"
}

resource "authentik_provider_oauth2" "argo-main-cluster" {
  name               = "main-cluster.argo"
  client_id          = "main-cluster.argo"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = "RS256"
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://argo.main-cluster.weebo.poc/api/dex/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://localhost:8085/auth/callback",
    },
  ]
}

resource "authentik_application" "argo-main-cluster" {
  name              = "main-cluster.argo"
  slug              = "main-cluster-argo"
  protocol_provider = authentik_provider_oauth2.argo-main-cluster.id
}

resource "vault_kv_secret_v2" "argo-main-cluster" {
  mount = "mc-authentik"
  name  = "argocd-client/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.argo-main-cluster.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.argo-main-cluster.client_secret,
      AUTHENTIK_URL           = "https://login.main-cluster.weebo.poc/application/o/${authentik_application.argo-main-cluster.slug}/",
    }
  )
}
