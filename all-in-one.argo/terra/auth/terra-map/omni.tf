# https://integrations.goauthentik.io/infrastructure/omni/
# https://registry.terraform.io/providers/goauthentik/authentik/latest/docs/resources/provider_saml

# TODO : Prepare the omni application

resource "authentik_property_mapping_provider_saml" "omni-mappings" {
  name       = "Omni SAML Mappings"
  saml_name  = "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name"
  expression = "return request.user.email"
}

resource "authentik_provider_saml" "omni" {
  name               = "omni"
  authorization_flow = data.authentik_flow.default-authorization-flow.id
  invalidation_flow  = data.authentik_flow.default-invalidation-flow.id
  acs_url            = "https://omni.4.weebo.fr/saml/acs"
  sp_binding         = "post"
  audience           = "https://omni.4.weebo.fr/saml/metadata"
  signing_kp         = data.authentik_certificate_key_pair.generated.id
  sign_assertion     = true
  sign_response      = true
  property_mappings = [
    authentik_property_mapping_provider_saml.omni-mappings.id,
  ]
  name_id_mapping = authentik_property_mapping_provider_saml.omni-mappings.id
}

resource "authentik_application" "omni" {
  name              = "omni"
  slug              = "omni"
  protocol_provider = authentik_provider_saml.omni.id
}

resource "vault_kv_secret_v2" "omni" {
  mount = "mc-authentik"
  name  = "omni/auth"
  data_json = jsonencode(
    {
      AUTHENTIK_URL = "https://login.4.weebo.fr/application/saml/${authentik_application.omni.slug}/metadata/",
    }
  )
}
