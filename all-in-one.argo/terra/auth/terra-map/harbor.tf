resource "authentik_provider_oauth2" "harbor" {
  name               = "harbor"
  client_id          = "harbor"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://harbor.4.weebo.fr/c/oidc/callback",
    },
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
    data.authentik_property_mapping_provider_scope.scope-offline.id,
  ]
}

resource "authentik_application" "harbor" {
  name              = "harbor"
  slug              = "harbor"
  protocol_provider = authentik_provider_oauth2.harbor.id
}

resource "vault_kv_secret_v2" "harbor" {
  mount = "mc-authentik"
  name  = "harbor/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.harbor.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.harbor.client_secret,
      AUTHENTIK_URL           = "https://login.4.weebo.fr/application/o/${authentik_application.harbor.slug}/",
    }
  )
}
