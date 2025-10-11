resource "authentik_user" "batleforc" {
  username  = "batleforc"
  name      = "Batleforc"
  groups    = [authentik_group.weebo_admin.id]
  is_active = true
  email     = "batleforc@weebo.poc"
}
