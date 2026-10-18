---
title: "RFC 0001 — Stalwart et weebo-stalwart"
description: "Une messagerie interne au cluster, et l'opérateur qui en gère les objets, credentials dans Vault"
rfc: 0001
status: Draft
authors: [batleforc]
created: 2026-10-18
updated: 2026-10-18
decided:
brick: 2.argo/helm/mail, github.com/batleforc/weebo-stalwart
supersedes: []
superseded-by: []
---

# RFC 0001 — Stalwart, messagerie interne, et l'opérateur weebo-stalwart

**Cette RFC vit désormais dans weebo-operator-kit :**
[`docs/rfc-0001-stalwart.md`](https://github.com/batleforc/weebo-operator-kit/blob/main/docs/rfc-0001-stalwart.md).
C'est la seule version tenue à jour ; cette page ne garde que son résumé.

On déploie Stalwart v0.16 dans le namespace `mail` comme seul serveur mail
du domaine interne `weebo.poc`, sans rien faire sortir du cluster. Un
nouvel opérateur, `weebo-stalwart`, généré depuis le template du kit
(v0.18.x), gère le domaine, les comptes d'envoi des apps (credentials dans
`mv/<app>/smtp`), les boîtes des utilisateurs (`StalwartAccount`, créées et
verrouillées par CR), les groupes et les listes. Le lien avec Authentik
appartient à la brique de liaison ([RFC 0002](/docs/rfc/0002-liaison)), et
les écritures suivent [RFC 0003](/docs/rfc/0003-authentik-ecritures).

Les ancres citées par les RFC 0002 et 0003 (D7, D8, D9, *Ce que la brique
de liaison consomme*, *Verrouillage*, *Exploitation*) sont dans la version
du kit.
