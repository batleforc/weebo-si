resource "authentik_group" "weebo_admin" {
  name      = "weebo_admin"
  superuser = true
}

resource "authentik_group" "weebo_user" {
  name      = "weebo_user"
  superuser = false
}
