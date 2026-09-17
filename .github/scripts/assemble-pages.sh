#!/usr/bin/env bash
# Assemble le site GitHub Pages a partir des deux docs deja buildees:
#   /weebo-si/      -> doc courante (Fumadocs + React Router, 0.docs)
#   /weebo-si/v2/   -> archive figee (VitePress, lue dans un worktree sur v2.0.0)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

new_build="0.docs/build/client"
legacy_build=".legacy-docs/0.docs/.vitepress/dist"
out="${PAGES_OUT_DIR:-dist}"

if [ ! -d "$new_build/weebo-si" ]; then
  echo "manque $new_build/weebo-si : lance 'yarn --cwd 0.docs build' d'abord" >&2
  exit 1
fi
if [ ! -d "$legacy_build" ]; then
  echo "manque $legacy_build : lance '.github/scripts/build-legacy-docs.sh' d'abord" >&2
  exit 1
fi

rm -rf "$out"
mkdir -p "$out"

# React Router prerend les pages sous <basename>/ mais laisse les assets et les
# fichiers de public/ a la racine de build/client : on remet les deux a plat,
# la racine de l'artifact Pages etant deja /weebo-si/.
cp -r "$new_build/weebo-si/." "$out/"
find "$new_build" -mindepth 1 -maxdepth 1 ! -name weebo-si -exec cp -r {} "$out/" \;

# L'archive est construite avec --base /weebo-si/v2/, elle se depose telle quelle.
mkdir -p "$out/v2"
cp -r "$legacy_build/." "$out/v2/"

# GitHub Pages ne sait pas reecrire les URLs : le 404 sert a la fois de shell
# SPA et de table de redirection vers /v2/.
node .github/scripts/make-404.mjs \
  "$new_build/__spa-fallback.html" \
  .github/pages/legacy-redirect.js \
  "$out/404.html"

echo "site assemble dans $out/ ($(find "$out" -name '*.html' | wc -l) pages html)"
