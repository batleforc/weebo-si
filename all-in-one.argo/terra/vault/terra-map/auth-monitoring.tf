resource "vault_policy" "authentik_monitoring" {
  name = "authentik_monitoring"

  policy = <<EOT
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/*" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/config" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/sub" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/metadata/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/sub" {
  capabilities = ["read","list"]
}

path "mc-authentik/metadata/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/vpn" {
  capabilities = ["read","list"]
}
path "mc-authentik/data/che-cluster/{{identity.entity.aliases.auth_kubernetes_225a14d3.metadata.service_account_namespace}}/vpn" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "mc-authentik/metadata/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/data/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "mc-authentik/metadata/che-cluster/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/data/che-cluster/*/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

path "mc-authentik/metadata/+/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}
path "mc-authentik/data/+/monitoring" {
  capabilities = ["create", "read", "update", "delete", "list","patch"]
}

EOT
}

resource "vault_kubernetes_auth_backend_role" "auth-monitoring" {
  role_name                        = "auth-monitoring"
  bound_service_account_names      = ["coroot","default"]
  bound_service_account_namespaces = ["coroot","monitoring"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.authentik_monitoring.name]
}