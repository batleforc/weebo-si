# Phase 1 replacement for terra-map/group.tf.
#
# The three groups move to AuthentikGroup CRs, but Terraform cannot simply
# forget them: `vault.tf` builds `vault_identity_group_alias` off
# `authentik_group.weebo_{moderator,admin}.name`, and every `*-access`
# policy binding still in this module resolves `.id`. Those are references to
# a *resource* that will no longer exist in the configuration.
#
# So group.tf is not deleted -- it is downgraded from `resource` to `data`.
# Terraform keeps reading the groups (and every `.id`/`.name` reference keeps
# working unchanged, because the data source exports both), while the operator
# owns their lifecycle.
#
# Install it with, from 2.terra/auth:
#   cp migration/group-as-data.tf terra-map/group.tf
# and leave terra-map/group.tf listed in kustomization.yaml.
#
# Run the state rm FIRST (migration/state-rm-job.yaml, PHASE=identity).
# Swapping this file in while the resources are still in state makes the next
# PostSync apply plan a destroy of all three groups.

# include_users = false keeps the members out of the state file; nothing here
# reads them, and weebo_user is the root of the hierarchy every user lands in.
data "authentik_group" "weebo_user" {
  name          = "weebo_user"
  include_users = false
}

data "authentik_group" "weebo_moderator" {
  name          = "weebo_moderator"
  include_users = false
}

data "authentik_group" "weebo_admin" {
  name          = "weebo_admin"
  include_users = false
}
