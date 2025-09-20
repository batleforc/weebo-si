resource "harbor_config_auth" "oidc" {
  auth_mode          = "oidc_auth"
  oidc_name          = "Weebo Authentik"
  oidc_endpoint      = data.vault_kv_secret_v2.harbor_auth.data.AUTHENTIK_URL
  oidc_client_id     = data.vault_kv_secret_v2.harbor_auth.data.AUTHENTIK_CLIENT_ID
  oidc_client_secret = base64decode(data.vault_kv_secret_v2.harbor_auth.data.AUTHENTIK_CLIENT_SECRET)
  oidc_scope         = "openid,profile,email,offline_access"
  oidc_verify_cert   = true
  oidc_auto_onboard  = true
  oidc_groups_claim  = "groups"
  oidc_admin_group   = "weebo_admin"
  oidc_user_claim    = "preferred_username"
}

resource "harbor_config_system" "main" {
  project_creation_restriction = "adminonly"
  robot_name_prefix            = "svc-weebo@"
  storage_per_project          = 10
}

resource "harbor_garbage_collection" "main" {
  schedule        = "Daily"
  delete_untagged = true
}