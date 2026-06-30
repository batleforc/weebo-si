resource "authentik_provider_oauth2" "s3" {
  name               = "s3"
  client_id          = "s3"
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  signing_key        = data.authentik_certificate_key_pair.generated.id
  allowed_redirect_uris = [
    {
      matching_mode = "strict",
      url           = "https://bucket.weebo.poc/rustfs/admin/v3/oidc/callback",
    },
    {
      matching_mode = "strict",
      url           = "https://bucket.weebo.poc/rustfs/admin/v3/oidc/callback/authentik",
    }
  ]
  property_mappings = [
    data.authentik_property_mapping_provider_scope.scope-email.id,
    data.authentik_property_mapping_provider_scope.scope-profile.id,
    data.authentik_property_mapping_provider_scope.scope-openid.id,
    data.authentik_property_mapping_provider_scope.scope-offline.id,
  ]
  grant_types = ["authorization_code"]

}

resource "authentik_application" "s3" {
  name              = "s3"
  slug              = "s3"
  protocol_provider = authentik_provider_oauth2.s3.id
  meta_icon         = "https://maxleriche.net/public/media/application/s3.png"
}

resource "vault_kv_secret_v2" "s3" {
  mount = "mv"
  name  = "s3/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_CLIENT_ID     = authentik_provider_oauth2.s3.client_id,
      AUTHENTIK_CLIENT_SECRET = authentik_provider_oauth2.s3.client_secret,
      AUTHENTIK_URL           = "https://auth.weebo.poc/application/o/${authentik_application.s3.slug}/",
    }
  )
}

resource "authentik_policy_binding" "s3-access" {
  target = authentik_application.s3.uuid
  group  = authentik_group.weebo_moderator.id
  order  = 0
}
