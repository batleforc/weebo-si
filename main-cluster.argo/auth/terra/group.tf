resource "authentik_group" "weebo_user" {
  name      = "weebo_user"
  superuser = false
}


resource "authentik_group" "weebo_admin" {
  name      = "weebo_admin"
  superuser = true
  parents   = authentik_group.weebo_user.id
}
