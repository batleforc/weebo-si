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
  domain           = "weebo"
  default          = true
  flow_device_code = authentik_flow.token-authentik-flow.uuid
  branding_logo    = data.authentik_brand.authentik-default.branding_logo
  branding_favicon = data.authentik_brand.authentik-default.branding_favicon
}
