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