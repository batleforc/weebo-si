#!/usr/bin/env bash
# Construit l'archive de la doc VitePress (saisons 1 & 2) servie sous
# /weebo-si/v2/. Les sources ne sont pas dupliquees dans l'arbre: elles sont
# lues dans un worktree jetable place sur le tag qui les porte encore.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/../.."

# v2.0.0 == le dernier etat de l'ancienne doc (identique a 84560e00^, le commit
# qui l'a retiree de develop). Surchargeable si l'archive doit un jour bouger:
# pointer LEGACY_DOCS_REF sur une branche dediee plutot que sur le tag.
ref="${LEGACY_DOCS_REF:-v2.0.0}"
worktree=".legacy-docs"
base="/weebo-si/v2/"

if ! git rev-parse --verify --quiet "${ref}^{commit}" >/dev/null; then
  echo "ref '$ref' introuvable: lance 'git fetch --tags' (la CI checkout en fetch-depth: 0)" >&2
  exit 1
fi
want="$(git rev-parse "${ref}^{commit}")"

# Worktree reutilise tel quel s'il est deja sur le bon commit, refait sinon.
if [ -e "$worktree" ]; then
  have="$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)"
  if [ "$have" != "$want" ]; then
    git worktree remove --force "$worktree" 2>/dev/null || rm -rf "$worktree"
  fi
fi
if [ ! -e "$worktree" ]; then
  git worktree add --detach --force "$worktree" "$want"
fi

if [ "${1:-}" = "--worktree-only" ]; then
  echo "worktree $worktree place sur $ref ($want)"
  exit 0
fi

# Le tag porte encore le package.json racine, dont `docs:build` construit 0.docs.
# Le sous-chemin passe par --base en CLI: les sources archivees restent intactes.
yarn --cwd "$worktree" install --frozen-lockfile
yarn --cwd "$worktree" run docs:build --base "$base"

node .github/scripts/inject-archive-banner.mjs "$worktree/0.docs/.vitepress/dist"

echo "archive $ref construite dans $worktree/0.docs/.vitepress/dist"
