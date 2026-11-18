{{/*
CNPG Clusters: metrics scraping, and backups to the RustFS tenant through the
barman-cloud plugin (2.argo/helm/database/main). Every Cluster gets the same
two pieces, so the Backups dashboard (2.argo/helm/monitoring/dashboards/
backups.json) sees them all the same way.

weebo-base.cnpgClusterSpec: lines to put in the Cluster's `spec`.

  spec:
    instances: 1
    {{- include "weebo-base.cnpgClusterSpec" (dict "backup" .Values.x.backup) | nindent 2 }}

  - inheritedMetadata: opts the instance pods into otel-node's annotation
    discovery on the exporter port (9187). Always on, backup or not.
  - plugins: WAL archiving to the ObjectStore below. Adding or removing it
    restarts the instances -- one instance here, so a short outage.

weebo-base.cnpgBackup: the objects next to the Cluster.

  {{- include "weebo-base.cnpgBackup" (dict "ctx" . "cluster" "forgejo-pg" "secretStore" "cred-store" "backup" .Values.x.backup) }}

  backup:
    enabled: true
    bucket: forgejo-backup        # s3.mainInstance.creds in 2.argo/helm/database/sub
    vaultKey: mv/forgejo/backup   # accesskey / secretkey of that bucket's user
    pg:
      schedule: "0 0 2 * * *"     # six fields, seconds first
      retention: 7d               # barman recovery window, [dwm]
    # optional: endpoint (s3-main.weebo.poc), caSecret {name, key}

  `namespace` defaults to the release's: pass it when the chart renders into
  argocd and places its objects by hand (auth/main).

  Renders <cluster>-backup-cred (ExternalSecret, keys accesskey/secretkey),
  <cluster>-backup (ObjectStore, s3://<bucket>/pg/<cluster>/) and
  <cluster>-daily (ScheduledBackup). The vault key has to be under
  mv/<namespace>/: the `auth-read` role only reads there.
*/}}
{{- define "weebo-base.cnpgClusterSpec" -}}
inheritedMetadata:
  annotations:
    io.opentelemetry.discovery.metrics.9187/enabled: "true"
    io.opentelemetry.discovery.metrics.9187/scraper: "prometheus_simple"
    io.opentelemetry.discovery.metrics.9187/config: |
      collection_interval: "60s"
      endpoint: "`endpoint`"
      metrics_path: "/metrics"
{{- if .backup.enabled }}
plugins:
  - name: barman-cloud.cloudnative-pg.io
    isWALArchiver: true
    parameters:
      barmanObjectName: {{ required "cnpgClusterSpec: cluster name" .cluster }}-backup
{{- end }}
{{- end -}}

{{- define "weebo-base.cnpgBackup" -}}
{{- $b := .backup -}}
{{- if $b.enabled -}}
{{- $ns := .namespace | default .ctx.Release.Namespace -}}
{{- $ca := $b.caSecret | default (dict "name" "weebo.poc" "key" "main-ca.crt") -}}
---
apiVersion: external-secrets.io/v1
kind: ExternalSecret
metadata:
  name: {{ .cluster }}-backup-cred
  namespace: {{ $ns }}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
spec:
  refreshPolicy: Periodic
  refreshInterval: 24h
  secretStoreRef:
    name: {{ .secretStore }}
  target:
    name: {{ .cluster }}-backup-cred
  data:
  - secretKey: accesskey
    remoteRef:
      key: {{ required "cnpgBackup: backup.vaultKey" $b.vaultKey }}
      property: accesskey
  - secretKey: secretkey
    remoteRef:
      key: {{ $b.vaultKey }}
      property: secretkey
---
# Restoring is a new Cluster bootstrapped with `recovery.source` pointing at
# this ObjectStore through the same plugin (CNPG docs, "Recovery").
apiVersion: barmancloud.cnpg.io/v1
kind: ObjectStore
metadata:
  name: {{ .cluster }}-backup
  namespace: {{ $ns }}
  annotations:
    argocd.argoproj.io/sync-wave: "1"
    # The CRD ships with the barman-cloud plugin (database app); on a fresh
    # bootstrap it may not exist yet at dry-run time.
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  retentionPolicy: {{ $b.pg.retention | quote }}
  configuration:
    destinationPath: s3://{{ required "cnpgBackup: backup.bucket" $b.bucket }}/pg
    endpointURL: https://{{ $b.endpoint | default "s3-main.weebo.poc" }}
    endpointCA:
      name: {{ $ca.name }}
      key: {{ $ca.key }}
    s3Credentials:
      accessKeyId:
        name: {{ .cluster }}-backup-cred
        key: accesskey
      secretAccessKey:
        name: {{ .cluster }}-backup-cred
        key: secretkey
    wal:
      compression: gzip
    data:
      compression: gzip
---
apiVersion: postgresql.cnpg.io/v1
kind: ScheduledBackup
metadata:
  name: {{ .cluster }}-daily
  namespace: {{ $ns }}
  annotations:
    argocd.argoproj.io/sync-wave: "3"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  schedule: {{ $b.pg.schedule | quote }}
  # One right away, so a broken setup shows on the first sync, not at night.
  immediate: true
  backupOwnerReference: self
  cluster:
    name: {{ .cluster }}
  method: plugin
  pluginConfiguration:
    name: barman-cloud.cloudnative-pg.io
{{- end -}}
{{- end -}}
