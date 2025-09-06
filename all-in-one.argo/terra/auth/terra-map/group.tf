resource "authentik_group" "weebo_user" {
  name         = "weebo_user"
  is_superuser = false
}

resource "authentik_group" "weebo_moderator" {
  name         = "weebo_moderator"
  is_superuser = false
  parent       = authentik_group.weebo_user.id
}


resource "authentik_group" "weebo_admin" {
  name         = "weebo_admin"
  is_superuser = true
  parent       = authentik_group.weebo_moderator.id
}
