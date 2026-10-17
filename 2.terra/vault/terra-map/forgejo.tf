# Le role `forgejo` sur son cluster CNPG (2.argo/helm/forgejo, postgres/).
#
# Genere ici et non par CNPG, pour la meme raison que batlehub.tf : le mot de
# passe doit exister AVANT le bootstrap, c'est l'ExternalSecret qui materialise
# le basic-auth que `bootstrap.initdb.secret` nomme.
resource "random_string" "forgejo-pg" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "forgejo-pg" {
  mount = "mv"
  name  = "forgejo/pg"
  data_json = jsonencode(
    {
      username = "forgejo"
      password = random_string.forgejo-pg.result
    }
  )
}

# L'admin local de Forgejo (gitea.admin.existingSecret), pour le jour ou
# Authentik ne repond pas. Le chart remet ce mot de passe a chaque demarrage
# (passwordMode: keepUpdated) : Vault reste la seule source. `admin` est un
# nom refuse par le chart.
resource "random_string" "forgejo-admin" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "forgejo-admin" {
  mount = "mv"
  name  = "forgejo/admin"
  data_json = jsonencode(
    {
      username = "forgejo_admin"
      password = random_string.forgejo-admin.result
    }
  )
}

# L'operateur weebo-forgejo (2.argo/helm/forgejo, operator.*) ecrit dans Vault
# les credentials que ses CRs emettent (applications OAuth2, tokens, mots de
# passe generes) quand une CR pose `secretTargets: [{backend: vault, ...}]`.
# Il se connecte avec son propre ServiceAccount, comme l'operateur authentik --
# mais avec une policy limitee au KV `mv`, pas mv_policy et ses droits sur
# sys/ et auth/.
resource "vault_policy" "forgejo_operator_policy" {
  name = "forgejo_operator_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/*" {
  capabilities = ["create", "read", "update", "delete"]
}
path "${vault_mount.main-vault.path}/metadata/*" {
  capabilities = ["read", "delete"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "forgejo-operator" {
  role_name                        = "forgejo-operator"
  bound_service_account_names      = ["weebo-forgejo"]
  bound_service_account_namespaces = ["weebo-forgejo"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.forgejo_operator_policy.name]
}
