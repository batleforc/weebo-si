resource "random_string" "batlehub-valkey" {
  length  = 42
  special = false
}


resource "vault_kv_secret_v2" "batlehub-valkey" {
  mount = "mv"
  name  = "batlehub/config"
  data_json = jsonencode(
    {
      pwd = random_string.batlehub-valkey.result
      url = "redis://batlehub:${random_string.batlehub-valkey.result}@valkey-batlehub-valkey.batlehub.svc:6379"
    }
  )
}

# Le role `batlehub` sur son cluster CNPG (2.argo/helm/batlehub, postgres/).
#
# Genere ici plutot que laisse a CNPG -- qui sait tres bien ecrire un
# `<cluster>-app` tout seul -- parce que le mot de passe doit exister AVANT le
# bootstrap : c'est l'ExternalSecret qui materialise le basic-auth que
# `bootstrap.initdb.secret` nomme. Le laisser a l'operateur voudrait dire
# recuperer un mot de passe du cluster pour le remettre dans Vault, dans ce
# sens-la.
#
# `special = false` n'est pas cosmetique : ce mot de passe part dans une URL
# `postgresql://batlehub:<pwd>@...`, ou un `@` ou un `/` couperait l'URL en
# deux. Meme raison que le valkey au-dessus.
resource "random_string" "batlehub-pg" {
  length  = 42
  special = false
}

resource "vault_kv_secret_v2" "batlehub-pg" {
  mount = "mv"
  name  = "batlehub/pg"
  data_json = jsonencode(
    {
      username = "batlehub"
      password = random_string.batlehub-pg.result
    }
  )
}

# Le token admin de l'operateur weebo-batlehub (2.argo/helm/batlehub,
# operator.*), qui pilote ce batlehub en mode `external`. Les deux faces du
# meme secret vont dans mv/batlehub/operator :
#
#   - `token`, en clair, lu par l'operateur (Secret batlehub-operator-token,
#     etiquete batlehub.weebo.io/instance-token) ;
#   - `token_hash`, l'argon2id que batlehub compare : il entre dans la config
#     par `${OPERATOR_TOKEN_HASH}` (`[[auth]] type = "token"`), le token en
#     clair n'atteint jamais le pod.
#
# Memes parametres que password_argon2.angos-scanner, pour la meme raison
# (angos.tf) : ce sont ceux d'Argon2::default() -- 19 MiB, 2 passes, 1 voie --
# que batlehub et l'operateur utilisent eux-memes, et epingles pour que le
# plan ne bouge pas d'un poste a l'autre. Changer le cout :
#   tofu apply -replace=password_argon2.batlehub-operator
#
# `random_password` et pas `random_string` : l'id d'un random_string EST sa
# valeur, et le plan comme l'apply l'affichent en clair dans les logs du job.
# Celui d'un random_password vaut `none`.
resource "random_password" "batlehub-operator" {
  length  = 48
  special = false
}

resource "password_argon2" "batlehub-operator" {
  password = random_password.batlehub-operator.result

  memory     = 19456
  iterations = 2
  thread     = 1
  key_len    = 32
}

resource "vault_kv_secret_v2" "batlehub-operator" {
  mount = "mv"
  name  = "batlehub/operator"
  data_json = jsonencode(
    {
      token      = random_password.batlehub-operator.result
      token_hash = password_argon2.batlehub-operator.hash
    }
  )
}
