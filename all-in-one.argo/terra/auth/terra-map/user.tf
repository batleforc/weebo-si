resource "authentik_user" "batleforc" {
  username  = "batleforc"
  name      = "Batleforc"
  groups    = [ for value in authentik_group : value.id ]
  is_active = true
  email     = "batleforc@weebo.poc"
}
