resource "authentik_user" "batleforc" {
  username  = "batleforc"
  name      = "Batleforc"
  groups    = [authentik_group.*.id]
  is_active = true
  email     = "batleforc@weebo.poc"
}
