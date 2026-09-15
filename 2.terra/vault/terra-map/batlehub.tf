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
