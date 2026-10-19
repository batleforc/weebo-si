# Stalwart, le serveur mail interne (2.argo/helm/mail, RFC 0001 -- la RFC vit
# dans weebo-operator-kit, docs/rfc-0001-stalwart.md). Domaine `weebo.internal`
# (D23 : Stalwart refuse `.poc`).
#
# `mv/mail/s3` est dans s3.tf, a cote de `forgejo/s3`. `mv/mail/auth` est ecrit
# par l'operateur authentik (application `stalwart`, 2.argo/helm/auth/sub).

# Le role `stalwart` du cluster CNPG `stalwart` (DataStore de config.json).
# Meme raison que forgejo.tf : le mot de passe doit exister AVANT le bootstrap
# CNPG.
resource "random_password" "mail-pg" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "mail-pg" {
  mount = "mv"
  name  = "mail/pg"
  data_json = jsonencode(
    {
      username = "stalwart"
      password = random_password.mail-pg.result
    }
  )
}

# L'admin de recovery (STALWART_RECOVERY_ADMIN=<username>:<password>) : le
# break-glass, et l'identite du Job `stalwart-bootstrap` (plan `apply`, ApiKeys de
# l'operateur). Comme mv/forgejo/admin. `special = false` : la valeur est
# coupee au premier `:` par Stalwart et rendue dans un plan JSON.
resource "random_password" "mail-admin" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "mail-admin" {
  mount = "mv"
  name  = "mail/admin"
  data_json = jsonencode(
    {
      username = "admin"
      password = random_password.mail-admin.result
    }
  )
}

# Comptes d'envoi de la phase 0 (RFC 0001, Rollout 1) : crees dans Stalwart par
# le plan du Job `stalwart-bootstrap`, avec ces mots de passe. La cle de la map
# est le nom du compte (`<cle>@weebo.internal`), `namespace` le namespace de
# l'app, donc le chemin `mv/<namespace>/smtp` que son ExternalSecret lit (le
# chemin que l'operateur ecrira, D15).
#
# Temporaire : a l'import de ces comptes par weebo-stalwart (phase 1), chaque
# entree est retiree d'ici AVANT l'import, qui force une rotation (D21) -- le
# mot de passe ecrit ici n'a pas d'owner Vault. Ces mots de passe ne marchent
# que tant que `oidc.default` est false dans le chart (D24) : on ne le passe a
# true qu'apres l'import, quand chaque compte a son App Password.
locals {
  mail_domain = "weebo.internal"
  mail_service_accounts = {
    forgejo   = { namespace = "forgejo", from = "noreply" }
    authentik = { namespace = "auth", from = "authentik" }
    argocd    = { namespace = "argocd", from = "argocd" }
  }
}

resource "random_password" "mail-service-account" {
  for_each = local.mail_service_accounts
  length   = 32
  special  = false
}

# Les cles annoncees par la RFC (Brancher une app) : ce que l'operateur ecrira.
resource "vault_kv_secret_v2" "mail-service-account" {
  for_each = local.mail_service_accounts
  mount    = "mv"
  name     = "${each.value.namespace}/smtp"
  data_json = jsonencode(
    {
      host     = "stalwart.mail.svc.cluster.local"
      port     = "587"
      security = "starttls"
      username = "${each.key}@${local.mail_domain}"
      password = random_password.mail-service-account[each.key].result
      from     = "${each.value.from}@${local.mail_domain}"
    }
  )
}

# Les memes mots de passe, cote serveur : le plan du Job les pose sur les
# comptes. Un seul chemin sous mv/mail/ pour que `mail-read` reste borne a ce
# namespace au lieu de lire tous les `mv/+/smtp`.
resource "vault_kv_secret_v2" "mail-accounts" {
  mount = "mv"
  name  = "mail/accounts"
  data_json = jsonencode(
    { for name, _ in local.mail_service_accounts : name => random_password.mail-service-account[name].result }
  )
}

# Les ExternalSecrets du namespace `mail` (SecretStore `cred-store`). Lecture
# seule, sur mv/mail/* uniquement : `mail` n'est pas dans `auth-read`.
resource "vault_policy" "mail_read_policy" {
  name = "mail_read_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/mail/*" {
  capabilities = ["read"]
}
path "${vault_mount.main-vault.path}/metadata/mail/*" {
  capabilities = ["read", "list"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "mail-read" {
  role_name                        = "mail-read"
  bound_service_account_names      = ["default"]
  bound_service_account_namespaces = ["mail"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.mail_read_policy.name]
}

# L'operateur weebo-stalwart (phase 1), sur `mv/<namespace>/smtp` seulement
# (RFC 0001, D15). `metadata` est indispensable : sans lui le kit n'enregistre
# ni ne verifie l'owner, et le check-and-set avec owner disparait en silence.
# Avec `pathPrefix: ""`, un chemin sans owner est adopte : c'est CETTE policy
# qui empeche un CR de reecrire mv/<ns>/admin ou mv/mail/*. L'elargir est un
# changement de securite, par RFC.
resource "vault_policy" "stalwart_operator_policy" {
  name = "stalwart_operator_policy"

  policy = <<EOT
path "${vault_mount.main-vault.path}/data/+/smtp" {
  capabilities = ["create", "read", "update", "delete"]
}
path "${vault_mount.main-vault.path}/metadata/+/smtp" {
  capabilities = ["create", "read", "update", "delete"]
}
EOT
}

resource "vault_kubernetes_auth_backend_role" "stalwart-operator" {
  role_name                        = "stalwart-operator"
  bound_service_account_names      = ["weebo-stalwart"]
  bound_service_account_namespaces = ["weebo-stalwart"]
  token_ttl                        = 3600
  token_policies                   = [vault_policy.stalwart_operator_policy.name]
}
