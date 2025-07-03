# Value based from the authentik documentation:
# https://integrations.goauthentik.io/integrations/services/netbird/

resource "authentik_provider_oauth2" "netbird" {
  name               = "netbird"
  client_id          = "netbird"
  client_type        = "public"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://netbird.4.weebo.fr",
    },
    {
      matching_mode = "strict",
      url           = "https://localhost:53000",
    },
    {
      matching_mode = "regex",
      url           = "https://netbird.4.weebo.fr.*",
    }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
    data.authentik_property_mapping_provider_scope.scope-offline.id,
    data.authentik_property_mapping_provider_scope.scope-api.id,
  ]
  access_code_validity = "minutes=10"
  sub_mode             = "user_id"
}

resource "authentik_user" "netbird_sa" {
  username = "NetBird"
  type     = "service_account"
  groups   = [authentik_group.weebo_admin.id]
}

resource "authentik_application" "netbird" {
  name              = "main-cluster.netbird"
  slug              = "main-cluster-netbird"
  protocol_provider = authentik_provider_oauth2.netbird.id
}

resource "vault_kv_secret_v2" "netbird" {
  mount = "mc-authentik"
  name  = "netbird/auth"
  data_json = jsonencode(
    {
      NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT = "https://login.4.weebo.fr/application/o/${authentik_application.netbird.slug}/.well-known/openid-configuration",
      NETBIRD_USE_AUTH0                        = "false",
      NETBIRD_AUTH_CLIENT_ID                   = authentik_provider_oauth2.netbird.client_id,
      NETBIRD_AUTH_SUPPORTED_SCOPES            = "openid profile email offline_access api",
      NETBIRD_AUTH_AUDIENCE                    = authentik_provider_oauth2.netbird.client_secret,
      NETBIRD_AUTH_DEVICE_AUTH_CLIENT_ID       = authentik_provider_oauth2.netbird.client_id,
      NETBIRD_AUTH_DEVICE_AUTH_AUDIENCE        = authentik_provider_oauth2.netbird.client_id,
      NETBIRD_MGMT_IDP                         = "authentik",
      NETBIRD_IDP_MGMT_CLIENT_ID               = authentik_provider_oauth2.netbird.client_id,
      NETBIRD_IDP_MGMT_EXTRA_USERNAME          = authentik_user.netbird_sa.username,
      NETBIRD_IDP_MGMT_EXTRA_PASSWORD          = authentik_user.netbird_sa.password,
    }
  )
}
