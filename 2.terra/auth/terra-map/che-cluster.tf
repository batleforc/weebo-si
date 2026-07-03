resource "authentik_provider_oauth2" "che" {
  name                  = "che-cluster"
  client_id             = "che-cluster"
  sub_mode              = "user_username"
  invalidation_flow     = data.authentik_flow.default-invalidation-flow.id
  authorization_flow    = data.authentik_flow.default-authorization-flow.id
  signing_key           = data.authentik_certificate_key_pair.generated.id
  access_token_validity = "hours=10"
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "http://localhost:8000",
    },
    {
      matching_mode = "strict",
      url           = "https://cde.weebo.poc/oauth/callback",
    },
    {
      matching_mode = "regex",
      url           = "https://.*.cde.weebo.poc/*.",
    },
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
    data.authentik_property_mapping_provider_scope.scope-offline.id,
  ]
  grant_types = ["authorization_code"]

}

resource "authentik_application" "che" {
  name              = "che-cluster"
  slug              = "che-cluster"
  protocol_provider = authentik_provider_oauth2.che.id
  meta_icon         = "https://maxleriche.net/public/media/application/eclipse-che.png"
  meta_launch_url   = "https://cde.weebo.poc"
}

resource "vault_kv_secret_v2" "che-app" {
  mount = "mv"
  name  = "eclipse-che/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.che.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.che.client_secret,
      AUTHENTIK_URL           = "https://auth.weebo.poc/application/o/${authentik_application.che.slug}/",
    }
  )
}

resource "vault_kv_secret_v2" "che-app-2" {
  mount = "mv"
  name  = "dex/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.che.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.che.client_secret,
      AUTHENTIK_URL           = "https://auth.weebo.poc/application/o/${authentik_application.che.slug}/",
    }
  )
}

resource "authentik_policy_binding" "che-access" {
  target = authentik_application.che.uuid
  group  = authentik_group.weebo_moderator.id
  order  = 0
}
