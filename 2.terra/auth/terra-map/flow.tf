resource "authentik_flow" "token-authentik-flow" {
  name           = "device-code-authentik-flow"
  title          = "Device Code Flow"
  slug           = "device-code-flow"
  designation    = "stage_configuration"
  authentication = "require_authenticated"
}

data "authentik_brand" "authentik-default" {
  domain = "authentik-default"
}

resource "authentik_brand" "default" {
  domain                           = "weebo"
  default                          = true
  branding_title                   = "Weebo Authentik"
  flow_device_code                 = authentik_flow.token-authentik-flow.uuid
  branding_logo                    = "https://maxleriche.net/assets/web-app-manifest-192x192.png"
  branding_favicon                 = "https://maxleriche.net/assets/favicon.svg"
  branding_default_flow_background = "https://maxleriche.net/assets/home_hero.png"
  default_application              = data.authentik_brand.authentik-default.default_application
  flow_authentication              = data.authentik_brand.authentik-default.flow_authentication
  flow_invalidation                = data.authentik_brand.authentik-default.flow_invalidation
  flow_recovery                    = data.authentik_brand.authentik-default.flow_recovery
  flow_unenrollment                = data.authentik_brand.authentik-default.flow_unenrollment
  flow_user_settings               = data.authentik_brand.authentik-default.flow_user_settings
}
