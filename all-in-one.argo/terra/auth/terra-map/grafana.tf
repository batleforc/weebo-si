resource "authentik_provider_oauth2" "grafana" {
  name               = "grafana"
  client_id          = "grafana"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://grafana.4.weebo.fr/login/generic_oauth",
    },
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
  ]
}

resource "authentik_application" "grafana" {
  name              = "grafana"
  slug              = "grafana"
  protocol_provider = authentik_provider_oauth2.grafana.id
}

resource "vault_kv_secret_v2" "grafana" {
  mount = "mc-authentik"
  name  = "grafana/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.grafana.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.grafana.client_secret,
      AUTHENTIK_URL           = "https://login.4.weebo.fr/application/o/${authentik_application.grafana.slug}/",
    }
  )
}
