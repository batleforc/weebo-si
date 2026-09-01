#!/bin/sh
# Phase 1 helper: repoint every `authentik_group.X` reference at the data
# source that migration/group-as-data.tf introduces. Run from 2.terra/auth
# AFTER the identity state rm has succeeded.
#
#   sh migration/rewrite-group-refs.sh
#
# user.tf is deleted rather than rewritten: authentik_user.batleforc becomes
# the AuthentikUser CR, and nothing else in the module references it.
set -eu
cd "$(dirname "$0")/.."

cp migration/group-as-data.tf terra-map/group.tf
rm -f terra-map/user.tf

for f in terra-map/*.tf; do
  [ "$f" = "terra-map/group.tf" ] && continue
  sed -i 's/\bauthentik_group\./data.authentik_group./g' "$f"
done

echo "rewritten. remaining references:"
grep -rn "authentik_group\." terra-map/ || true
echo
echo "Now drop ./terra-map/user.tf from kustomization.yaml's configMapGenerator"
echo "and let ArgoCD sync. terraform plan must report no changes."
