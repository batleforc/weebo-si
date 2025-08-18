resource "authentik_provider_oauth2" "che" {
  name               = "che-cluster"
  client_id          = "che-cluster"
  sub_mode           = "user_email"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "http://localhost:8000",
    },
    {
      matching_mode = "strict",
      url           = "https://che-cluster.cluster.4.weebo.fr",
    },
    {
      matching_mode = "regex",
      url           = "https://.*.che-cluster.cluster.4.weebo.fr",
    },
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
  ]
}

resource "authentik_application" "che" {
  name              = "che-cluster"
  slug              = "che-cluster"
  protocol_provider = authentik_provider_oauth2.che.id
}

resource "vault_kv_secret_v2" "che" {
  mount = "mc-authentik"
  name  = "che/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.che.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.che.client_secret,
      AUTHENTIK_URL           = "https://login.4.weebo.fr/application/o/${authentik_application.che.slug}/",
    }
  )
}

resource "vault_kv_secret_v2" "che-app" {
  mount = "mc-authentik"
  name  = "che-cluster/eclipse-che/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.che.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.che.client_secret,
      AUTHENTIK_URL           = "https://login.4.weebo.fr/application/o/${authentik_application.che.slug}/",
    }
  )
}
