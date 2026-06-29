resource "authentik_user" "batleforc" {
  username  = "batleforc"
  name      = "max"
  groups    = [authentik_group.weebo_admin.id]
  is_active = true
  email     = "max@weebo.poc"
}
