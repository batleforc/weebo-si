{{/*
The `stalwart-cli apply` plan of the bootstrap (RFC 0001, phase 0), as NDJSON:
one operation per line, run in order, each `upsert` matched on its label
property (or `matchOn`) so a second run updates instead of duplicating.
Object and field names are those of Stalwart v0.16.27's schema (GET
/api/schema). `#<id>` are plan references, resolved by the server.

`${VAR}` placeholders are filled from the bootstrap pod's environment by the
`prepare` container (bootstrap.yaml): they are the only secrets the plan
carries. The S3 keys are not among them -- Stalwart reads them from its own
environment (`EnvironmentVariable`).
*/}}
{{- define "mail.plan" -}}
{{- $s := .Values.stalwart -}}
{{- $b := .Values.bootstrap -}}
{{- $o := .Values.oidc -}}
{{- $ns := .Release.Namespace -}}
{{- /* The domain. Manual certificates and DNS, no relaying; DKIM keys generated
       with the server's defaults, never published (internal domain). */ -}}
{{- dict "@type" "upsert" "object" "Domain" "matchOn" (list "name") "value" (dict "domain" (dict
      "name" $s.domain
      "subAddressing" (dict "@type" "Enabled")
      "dkimManagement" (dict "@type" "Automatic")
      "certificateManagement" (dict "@type" "Manual")
      "dnsManagement" (dict "@type" "Manual")
      "allowRelaying" false
    )) | toJson }}
{{/* The listeners' certificate: the files cert-manager mounts, not a copy. */ -}}
{{- dict "@type" "upsert" "object" "Certificate" "matchOn" (list "certificate") "value" (dict "cert" (dict
      "certificate" (dict "@type" "File" "filePath" "/etc/stalwart-tls/tls.crt")
      "privateKey" (dict "@type" "File" "filePath" "/etc/stalwart-tls/tls.key")
    )) | toJson }}
{{/* EHLO/banner name (D23: same validator as domains), default domain for a
       login without one, certificate for a client without SNI. */ -}}
{{- dict "@type" "update" "object" "SystemSettings" "value" (dict
      "defaultHostname" $s.hostname
      "defaultDomainId" "#domain"
      "defaultCertificateId" "#cert"
    ) | toJson }}
{{/* Submission. The image only listens on 25 and 465 for SMTP; a new
       listener is bound at the next start (the bootstrap restarts the
       StatefulSet when this creates it). */ -}}
{{- dict "@type" "upsert" "object" "NetworkListener" "matchOn" (list "name") "value" (dict "submission" (dict
      "name" "submission"
      "protocol" "smtp"
      "bind" (dict "[::]:587" true)
      "useTls" true
      "tlsImplicit" false
    )) | toJson }}
{{/* Blobs to RustFS, path-style (always, for a custom region). Read at start
       only: the bootstrap restarts the StatefulSet when it switches. */ -}}
{{- dict "@type" "update" "object" "BlobStore" "value" (dict
      "@type" "S3"
      "bucket" .Values.s3.bucket
      "region" (dict "@type" "Custom" "customEndpoint" .Values.s3.endpoint "customRegion" .Values.s3.region)
      "accessKey" (dict "@type" "EnvironmentVariable" "variableName" "STALWART_S3_ACCESS_KEY")
      "secretKey" (dict "@type" "EnvironmentVariable" "variableName" "STALWART_S3_SECRET_KEY")
    ) | toJson }}
{{/* The Oidc directory against Authentik, created in phase 0 even while
       it is not the default one. `usernameDomain` must name an existing
       x:Domain, or every JIT login fails. `claimUsername` is sent although
       it is the server's default (preferred_username). */ -}}
{{- dict "@type" "upsert" "object" "Directory" "matchOn" (list "description") "value" (dict "oidc" (dict
      "@type" "Oidc"
      "description" "Authentik"
      "issuerUrl" "${OIDC_ISSUER}"
      "requireAudience" "${OIDC_CLIENT_ID}"
      "claimUsername" $o.claimUsername
      "usernameDomain" $s.domain
      "claimName" $o.claimName
      "claimGroups" $o.claimGroups
    )) | toJson }}
{{/* values.yaml, oidc.default: null keeps the internal directory, so the
       sending accounts' passwords work (phase 0, D24). Written either way,
       so turning it off reverts it. */ -}}
{{- dict "@type" "update" "object" "Authentication" "value" (dict
      "directoryId" (ternary "#oidc" nil $o.default)
    ) | toJson }}
{{/* Accounts, matched on (name, domain). The sending accounts: role User, no
       IMAP/POP3/Sieve login, no reception (RFC 0001, StalwartServiceAccount);
       with oidc.default false, `credentials` is sent whole, which is fine for
       them in phase 0 (no app password, no API key) and resets a password
       changed by hand. With oidc.default true, never: Stalwart refuses any
       Password write to an account of an external directory (D24), and
       their credentials are App Passwords by then. The operator's
       account: no credential at all -- its API key is created by the
       recovery admin, and sending `credentials` would delete it. */ -}}
{{- $accounts := dict -}}
{{- range $b.serviceAccounts -}}
{{- $aliases := dict -}}
{{- range $i, $a := (.aliases | default list) -}}
{{- $_ := set $aliases (toString $i) (dict "name" $a "domainId" "#domain" "enabled" true) -}}
{{- end -}}
{{- $account := dict
      "@type" "User"
      "name" .name
      "domainId" "#domain"
      "roles" (dict "@type" "User")
      "encryptionAtRest" (dict "@type" "Disabled")
      "permissions" (dict
        "@type" "Merge"
        "enabledPermissions" (dict)
        "disabledPermissions" (dict "imapAuthenticate" true "pop3Authenticate" true "sieveAuthenticate" true "emailReceive" true)
      )
      "aliases" $aliases
    -}}
{{- if not $o.default -}}
{{- $_ := set $account "credentials" (dict "0" (dict "@type" "Password" "secret" (printf "${%s}" (include "mail.passwordVar" .name)))) -}}
{{- end -}}
{{- $_ := set $accounts (printf "account-%s" .name) $account -}}
{{- end -}}
{{- $_ := set $accounts "operator" (dict
      "@type" "User"
      "name" $b.operatorAccount
      "domainId" "#domain"
      "roles" (dict "@type" "Admin")
    ) -}}
{{- dict "@type" "upsert" "object" "Account" "matchOn" (list "name" "domainId") "value" $accounts | toJson }}
{{- end -}}

{{/* The environment variable carrying a sending account's password. */}}
{{- define "mail.passwordVar" -}}
SMTP_PASSWORD_{{ . | upper | replace "-" "_" }}
{{- end -}}
