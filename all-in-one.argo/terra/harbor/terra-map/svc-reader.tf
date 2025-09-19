resource "harbor_robot_account" "reader" {
  name = "reader"
  description = "Service account meant to be a read-only user for pulling images from Harbor"
  level = "system"
  permissions {
    namespace = harbor_project.cache-dck.name
    kind = "project"
    access {
      action = "pull"
      resource = "repository"
    }
  }
  permissions {
    namespace = harbor_project.cache-ghub.name
    kind = "project"
    access {
      action = "pull"
      resource = "repository"
    }
  }
  permissions {
    namespace = harbor_project.cache-quay.name
    kind = "project"
    access {
      action = "pull"
      resource = "repository"
    }
  }
}


variable "namespace_who_read" {
  type = map(string)
  default = {
    "harbor" = "harbor"
    "netbird" = "netbird"
    "che-cluster/che" = "che-cluster/che"
    "coroot" = "coroot"
    "argocd" = "argocd"
    "indns" = "indns"
  }
}

resource "vault_kv_secret_v2" "harbor_reader" {
  mount = "mc-authentik"
  for_each = var.namespace_who_read
  name  = "${each.key}/harbor"
  data_json = jsonencode(
    {
      username = harbor_robot_account.reader.name
      password = harbor_robot_account.reader.token
      url     = "https://harbor.4.weebo.fr"
    }
  )
}
