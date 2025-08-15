resource "authentik_provider_oauth2" "open-unison" {
  name               = "open-unison"
  client_id          = "open-unison"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://argo.main-cluster.weebo.poc/auth/oidc",
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
}

resource "authentik_application" "open-unison" {
  name              = "open-unison"
  slug              = "open-unison"
  protocol_provider = authentik_provider_oauth2.open-unison.id
}

resource "vault_kv_secret_v2" "open-unison" {
  mount = "mc-authentik"
  name  = "open-unison/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.open-unison.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.open-unison.client_secret,
      AUTHENTIK_URL           = "https://login.main-cluster.weebo.poc/application/o/${authentik_application.open-unison.slug}/",
    }
  )
}
