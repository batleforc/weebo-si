resource "authentik_provider_oauth2" "vault" {
  name               = "vault"
  client_id          = "vault"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://vault.4.weebo.fr/ui/vault/auth/authentik/oidc/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://vault.4.weebo.fr/authentik/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://vault.weebo.poc/ui/vault/auth/authentik/oidc/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://vault.weebo.poc/authentik/callback",
    },
    {
      matching_mode = "strict",
      url           = "http://localhost:8250/authentik/callback",
    }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
    data.authentik_property_mapping_provider_scope.scope-offline.id,
  ]
}

resource "authentik_application" "vault" {
  name              = "vault"
  slug              = "vault"
  protocol_provider = authentik_provider_oauth2.vault.id
}

resource "vault_jwt_auth_backend" "vault_authentik" {
  description        = "WeeboSI Authentik OIDC"
  path               = "authentik"
  type               = "oidc"
  oidc_discovery_url = "https://login.4.weebo.fr/application/o/${authentik_application.vault.slug}/"
  oidc_client_id     = authentik_provider_oauth2.vault.client_id
  oidc_client_secret = authentik_provider_oauth2.vault.client_secret
  default_role       = "reader"
}

resource "vault_jwt_auth_backend_role" "vault_authentik_reader" {
  backend        = vault_jwt_auth_backend.vault_authentik.path
  role_name      = "reader"
  token_policies = ["reader"]

  user_claim      = "sub"
  role_type       = "oidc"
  bound_audiences = [authentik_provider_oauth2.vault.client_id]
  allowed_redirect_uris = [
    "https://vault.4.weebo.fr/ui/vault/auth/authentik/oidc/callback",
    "https://vault.4.weebo.fr/authentik/callback",
    "https://vault.weebo.poc/ui/vault/auth/authentik/oidc/callback",
    "https://vault.weebo.poc/authentik/callback",
    "http://localhost:8250/authentik/callback",
  ]
  groups_claim = "groups"
  oidc_scopes  = ["openid", "profile", "email"]
}

resource "vault_identity_group" "vault_authentik_reader" {
  name     = "reader"
  type     = "external"
  policies = ["reader"]
}

resource "vault_identity_group_alias" "vault_authentik_reader" {
  name           = authentik_group.weebo_moderator.name
  mount_accessor = vault_jwt_auth_backend.vault_authentik.accessor
  canonical_id   = vault_identity_group.vault_authentik_reader.id
}

resource "vault_jwt_auth_backend_role" "vault_authentik_weebo_admin" {
  backend        = vault_jwt_auth_backend.vault_authentik.path
  role_name      = "weebo_admin"
  token_policies = ["weebo_admin", "root"]

  user_claim      = "sub"
  role_type       = "oidc"
  bound_audiences = [authentik_provider_oauth2.vault.client_id]
  allowed_redirect_uris = [
    "https://vault.4.weebo.fr/ui/vault/auth/authentik/oidc/callback",
    "https://vault.4.weebo.fr/authentik/callback",
    "https://vault.weebo.poc/ui/vault/auth/authentik/oidc/callback",
    "https://vault.weebo.poc/authentik/callback",
    "http://localhost:8250/authentik/callback",
  ]
  groups_claim = "groups"
  oidc_scopes  = ["openid", "profile", "email"]
}

resource "vault_identity_group" "vault_authentik_weebo_admin" {
  name     = "weebo_admin"
  type     = "external"
  policies = ["weebo_admin", "root"]
}

resource "vault_identity_group_alias" "vault_authentik_weebo_admin" {
  name           = authentik_group.weebo_admin.name
  mount_accessor = vault_jwt_auth_backend.vault_authentik.accessor
  canonical_id   = vault_identity_group.vault_authentik_weebo_admin.id
}
