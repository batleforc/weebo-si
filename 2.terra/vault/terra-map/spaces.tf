# Human secret spaces, outside `mv` on purpose: forgejo_operator_policy and
# mv_policy write anywhere in `mv/data/*`, so a user's or an org's secrets
# there would be readable by those workloads. The policies that open these
# mounts live in 2.terra/auth/terra-map/vault-spaces.tf, next to the OIDC
# accessor they template on.

# users/<authentik username>/<anything>
resource "vault_mount" "users" {
  path        = "users"
  type        = "kv"
  options     = { version = "2" }
  description = "Per-user personal space"
}

# <env mount>/<org>/<repo>/<secret...>. One mount per env so prod can be
# audited, sealed off or backed up on its own. Same list as
# vault_org_roles in 2.terra/auth/terra-map/vault-spaces.tf.
resource "vault_mount" "orgs" {
  for_each    = toset(["orgs-prod", "orgs-preprod", "orgs-recette", "orgs-devenv"])
  path        = each.key
  type        = "kv"
  options     = { version = "2" }
  description = "Organisation secrets, ${trimprefix(each.key, "orgs-")}"
}
