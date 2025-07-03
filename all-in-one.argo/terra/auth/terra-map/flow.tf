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
  domain           = data.authentik_brand.authentik-default.domain
  default          = true
  flow_device_code = authentik_flow.token-authentik-flow.id
}
