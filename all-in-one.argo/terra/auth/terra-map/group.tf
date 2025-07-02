resource "authentik_group" "weebo_user" {
  name         = "weebo_user"
  is_superuser = false
}


resource "authentik_group" "weebo_admin" {
  name         = "weebo_admin"
  is_superuser = true
  parent       = authentik_group.weebo_user.id
}
