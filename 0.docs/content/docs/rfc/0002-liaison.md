---
title: "RFC 0002 — La brique de liaison entre opérateurs"
description: "Relier les CR de deux opérateurs par des en-têtes link.weebo.io, un petit contrôleur weebo-link et des hooks d'admission natifs, sans CRD"
rfc: 0002
status: Draft
authors: [batleforc]
created: 2026-10-18
updated: 2026-10-18
decided:
brick: 2.argo/helm/link, github.com/batleforc/weebo-link
supersedes: []
superseded-by: []
---

# RFC 0002 — La brique de liaison : en-têtes `link.weebo.io`, `weebo-link` et hooks d'admission

**Cette RFC vit désormais dans weebo-operator-kit :**
[`docs/rfc-0002-liaison.md`](https://github.com/batleforc/weebo-operator-kit/blob/main/docs/rfc-0002-liaison.md).
C'est la seule version tenue à jour ; cette page ne garde que son résumé.

Un `AuthentikUser` annoté `link.weebo.io/stalwart: enabled` dans Git donne
un `StalwartAccount` dans `mail`. Un petit contrôleur sans CRD,
`weebo-link`, lit les règles de lien dans ses values Helm, crée les cibles
par server-side apply, et au départ de la source les passe dans leur état
sûr (`Locked`) au lieu de les supprimer. Des `ValidatingAdmissionPolicy`
natives valident les en-têtes et réservent l'écriture des cibles à
weebo-link, sans Kyverno ni webhook.

Ce que la RFC 0001 cite d'elle (l'expression `safe`, l'état `Detached`,
*Contrat d'une brique cible*, les décisions D1 à D10) est dans la version
du kit.
