resource "random_string" "angos-valkey" {
  length  = 42
  special = false
}

# `random_id` rather than the `random_string` above: angos wants a base64 HMAC
# key and validates that it decodes to at least 32 bytes, which a 42-character
# alphanumeric string does not survive.
resource "random_id" "angos-token-service" {
  byte_length = 32
}

# Encrypts the oauth2-proxy session cookie, which is where the browser's ID
# token lives between requests. oauth2-proxy takes 16, 24 or 32 bytes: it first
# tries to base64-decode this value and falls back to the raw string, so 32
# alphanumeric characters are accepted either way. Rotating it logs every
# browser out; no registry token or OIDC token is affected.
resource "random_string" "angos-oauth2-cookie" {
  length  = 32
  special = false
}

resource "vault_kv_secret_v2" "angos-valkey" {
  mount = "mv"
  name  = "angos/config"
  data_json = jsonencode(
    {
      pwd = random_string.angos-accessKey.result
      url = "redis://angos:${random_string.angos-accessKey.result}@valkey-angos-valkey.angos.svc:6379"
      # Signs the bearer tokens `GET /token` hands out. Rotating it invalidates
      # every registry token already issued; the OIDC ones are untouched.
      token_service_key = random_id.angos-token-service.b64_std
      # Read by the oauth2-proxy that fronts the web UI (2.argo/helm/angos).
      # Kept here rather than in `angos/auth` because that path is written by
      # the Authentik operator's `secretTargets` and would drop any key it does
      # not own.
      oauth2_cookie_secret = random_string.angos-oauth2-cookie.result
    }
  )
}

# L'identite avec laquelle le scanner d'images tire les images qu'il analyse
# (2.argo/helm/angos, angos.scanner). C'est la seule identite Basic de
# l'instance : `[scanner.registry]` prend un mot de passe statique et rien ne le
# fait tourner, la ou le jeton projete qu'utilise tout le reste du cluster
# serait perime dans l'heure.
#
# `special = false` n'est pas cosmetique : ce mot de passe est rendu tel quel
# dans une chaine TOML (scanner.toml), ou un guillemet ou un antislash casserait
# le fichier.
resource "random_password" "angos-scanner" {
  length  = 48
  special = false
}

# Le bearer que le registre presente au scanner, et que le scanner exige.
# Symetrique et en clair des deux cotes, donc rien a deriver.
resource "random_string" "angos-scan-token" {
  length  = 48
  special = false
}

# angos stocke le mot de passe ci-dessus hashe en argon2id, format PHC, et le
# verifie en recalculant avec les parametres ecrits DANS la chaine. D'ou un
# provider dedie : il faut une chaine `$argon2id$v=19$m=..,t=..,p=..$sel$hash`
# complete, pas un digest nu.
#
# Les quatre parametres sont epingles, et ce n'est pas du zele :
#
#   - `memory` vaut 2097152 KiB par defaut, soit 2 GiB. angos alloue cette
#     memoire a CHAQUE verification Basic, et son pod est limite a 500Mi :
#     laisser le defaut, c'est faire tuer le registre par l'OOM killer au
#     premier pull du scanner. 19456 est la valeur que `angos argon` utilise
#     lui-meme.
#   - `thread` vaut runtime.NumCPU() par defaut, donc la valeur planifiee bouge
#     d'une machine a l'autre. Le hash resterait valide -- le p est dans la
#     chaine -- mais le plan afficherait un diff selon le poste qui l'execute.
#   - `iterations` et `key_len` suivent, pour que la chaine produite soit celle
#     que `angos argon` produirait.
#
# A savoir avant d'y toucher : l'Update() du provider ne recalcule le hash que
# si `password` change. Modifier un parametre de cout ici l'ecrit dans le state
# sans refaire le hash, et le state decrit alors un hash qu'il n'a pas. Pour
# changer le cout, remplacer la ressource :
#   tofu apply -replace=password_argon2.angos-scanner
resource "password_argon2" "angos-scanner" {
  password = random_password.angos-scanner.result

  memory     = 19456
  iterations = 2
  thread     = 1
  key_len    = 32
}

# Les deux faces du meme mot de passe, plus le bearer. Chemin separe de
# `angos/config` parce que celui-la est ecrit en entier par la ressource plus
# haut et n'accepte pas de cle qu'il ne connait pas.
#
# Lisible par le namespace angos sans policy supplementaire : mv_reader_policy
# couvre deja mv/<namespace>/* (auth-base.tf).
resource "vault_kv_secret_v2" "angos-scanner" {
  mount = "mv"
  name  = "angos/scanner"
  data_json = jsonencode(
    {
      password      = random_password.angos-scanner.result
      password_hash = password_argon2.angos-scanner.hash
      token         = random_string.angos-scan-token.result
    }
  )
}
