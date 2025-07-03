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

resource "random_password" "netbird_sa_password" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "authentik_user" "netbird_sa" {
  username = "netbird"
  type     = "service_account"
  groups   = [authentik_group.weebo_admin.id]
  password = random_password.netbird_sa_password.result
}



resource "authentik_application" "netbird" {
  name              = "netbird"
  slug              = "netbird"
  protocol_provider = authentik_provider_oauth2.netbird.id
}

resource "random_string" "encryption_key" {
  length  = 32
  special = true
}

resource "random_password" "netbird_turn_server_password" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "random_password" "netbird_relay_password" {
  length           = 32
  special          = true
  override_special = "_-"
}

resource "vault_kv_secret_v2" "netbird" {
  mount = "mc-authentik"
  name  = "netbird/auth"
  data_json = jsonencode(
    {
      NETBIRD_AUTH_OIDC_CONFIGURATION_ENDPOINT = "https://login.4.weebo.fr/application/o/${authentik_application.netbird.slug}/.well-known/openid-configuration",
      NETBIRD_AUTH_BASE_URL                    = "https://login.4.weebo.fr/application/o/${authentik_application.netbird.slug}",
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
      NETBIRD_DATASTORE_ENCRYPTION_KEY         = base64encode(random_string.encryption_key.result),
      NETBIRD_TURN_SERVER_USER                 = "netbirdturnserveruser"
      NETBIRD_TURN_SERVER_PASSWORD             = random_password.netbird_turn_server_password.result,
      NETBIRD_REPLAY_PASSWORD                  = random_password.netbird_relay_password.result,
    }
  )
}
