resource "authentik_provider_oauth2" "argo" {
  name               = "argo"
  client_id          = "argo"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://argo.weebo.poc/api/dex/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://localhost:8085/auth/callback",
    },
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
  ]
  grant_types = ["authorization_code"]
}

resource "authentik_application" "argo" {
  name              = "argo"
  slug              = "argo"
  protocol_provider = authentik_provider_oauth2.argo.id
  meta_icon         = "https://maxleriche.net/public/media/techno/argo.png"
}

resource "vault_kv_secret_v2" "argo" {
  mount = "mv"
  name  = "argocd/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.argo.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.argo.client_secret,
      AUTHENTIK_URL           = "https://auth.weebo.poc/application/o/${authentik_application.argo.slug}/",
    }
  )
}

resource "authentik_policy_binding" "argo-access" {
  target = authentik_application.argo.uuid
  group  = data.authentik_group.weebo_moderator.id
  order  = 0
}
