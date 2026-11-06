# Who reaches the `users` and `orgs-<env>` KV mounts (created by
# 2.terra/vault/terra-map/spaces.tf). Humans only, through the authentik OIDC
# backend of vault.tf.

locals {
  vault_oidc_accessor = vault_jwt_auth_backend.vault_authentik.accessor

  # Forgejo organisations, i.e. the first segment under each orgs-<env>
  # mount. Each gets one Authentik group per role below, named
  # `<org>_<role>` (2.argo/helm/auth/sub identity.groups). `reader` has no
  # group here: it can do nothing in Vault.
  vault_orgs = ["batleforc-org"]

  # Role => env mount => level.
  vault_org_roles = {
    owner = {
      orgs-prod = "owner", orgs-preprod = "owner", orgs-recette = "owner", orgs-devenv = "owner"
    }
    maintainer = {
      orgs-prod = "write", orgs-preprod = "write", orgs-recette = "write", orgs-devenv = "write"
    }
    dev = {
      orgs-preprod = "read", orgs-recette = "write", orgs-devenv = "write"
    }
  }

  # KV v2 capabilities per level. Only `owner` deletes: soft delete on data,
  # undelete/destroy of versions, and the whole history through metadata.
  vault_org_levels = {
    read  = { data = ["read"], metadata = ["read", "list"] }
    write = { data = ["create", "read", "update", "patch"], metadata = ["read", "list"] }
    owner = { data = ["create", "read", "update", "patch", "delete"], metadata = ["read", "list", "delete"] }
  }

  vault_org_grants = {
    for p in setproduct(local.vault_orgs, keys(local.vault_org_roles)) :
    "${p[0]}_${p[1]}" => { org = p[0], role = p[1] }
  }
}

# users/<username>/*. `username` is the alias metadata set from the
# preferred_username claim by the roles' claim_mappings (vault.tf). If the
# claim is missing, Vault drops the templated path instead of opening
# users/data//*.
resource "vault_policy" "user_space" {
  name = "user_space"

  policy = <<EOT
path "users/data/{{identity.entity.aliases.${local.vault_oidc_accessor}.metadata.username}}/*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list"]
}
path "users/metadata/{{identity.entity.aliases.${local.vault_oidc_accessor}.metadata.username}}/*" {
  capabilities = ["read", "list", "delete"]
}
EOT
}

# <env mount>/<org>/<repo>/<secret...>: `+` is exactly one segment, so a
# secret always sits under a repo.
resource "vault_policy" "org" {
  for_each = local.vault_org_grants
  name     = "org_${each.key}"

  policy = join("\n", flatten([
    for mount, level in local.vault_org_roles[each.value.role] : concat(
      [<<EOT
path "${mount}/data/${each.value.org}/+/*" {
  capabilities = ${jsonencode(local.vault_org_levels[level].data)}
}
path "${mount}/metadata/${each.value.org}/*" {
  capabilities = ${jsonencode(local.vault_org_levels[level].metadata)}
}
EOT
      ],
      level != "owner" ? [] : [for op in ["delete", "undelete", "destroy"] : <<EOT
path "${mount}/${op}/${each.value.org}/+/*" {
  capabilities = ["update"]
}
EOT
      ]
    )
  ]))
}

# Membership comes from the `groups` claim at each login (groups_claim on
# both roles), so adding someone to the Authentik group is all it takes.
resource "vault_identity_group" "org" {
  for_each = local.vault_org_grants
  name     = "org_${each.key}"
  type     = "external"
  policies = [vault_policy.org[each.key].name]
}

resource "vault_identity_group_alias" "org" {
  for_each       = local.vault_org_grants
  name           = each.key
  mount_accessor = local.vault_oidc_accessor
  canonical_id   = vault_identity_group.org[each.key].id
}
