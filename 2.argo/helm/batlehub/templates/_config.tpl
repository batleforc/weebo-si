{{/*
batlehub's config.toml, as YAML, without `registries`: everything but the
registries, rendered once for two readers --

  - the upstream chart's `config` (batlehub/app.yaml), which seeds the
    writable config file at every pod start;
  - the BatleHubLocalInstance's `spec.config` (operator/instance.yaml), which
    the operator pushes, with the BatleHubRegistry objects
    (operator/registries.yaml) rendered after it.

One template, so the two cannot disagree: the file a pod starts on is the one
the operator would push, and its first push after a restart changes nothing.

Takes the chart's top-level context.
*/}}
{{- define "batlehub.serverConfig" -}}
{{- $root := . -}}
{{- $b := $root.Values.batlehub -}}
server:
  host: "0.0.0.0"
  port: 8080
  static_dir: "/app/ui/dist"
  trusted_proxies:
    {{- toYaml $b.trustedProxies | nindent 4 }}
{{- if $b.subdomainRouting.enabled }}
subdomain_routing:
  enabled: true
  base_domain: {{ $b.dns }}
  # Only ever used to ADVERTISE a URL (npm's dist.tarball, the cargo
  # index's dl, the PyPI simple index). A request's own scheme is
  # what routes it.
  scheme: https
{{- end }}
database:
  type: postgresql
  url: "postgresql://{{ $b.postgres.owner }}:${DB_PASSWORD}@batlehub-pg-rw.{{ $root.Release.Namespace }}.svc:5432/{{ $b.postgres.database }}"
storage:
  {{- if eq $b.storage.type "filesystem" }}
  type: filesystem
  path: {{ $b.storage.filesystem.path }}
  {{- else }}
  type: s3
  bucket: {{ $b.storage.s3.bucket }}
  region: {{ $b.storage.s3.region }}
  endpoint_url: {{ $b.storage.s3.url }}
  # RustFS addresses buckets by path, not by virtual host.
  force_path_style: true
  # The chart's default storage block is the filesystem one, and Helm
  # merges maps key by key, so its `path` survives into this `[storage]`:
  # the `null` that would delete it never reaches Helm, Argo CD drops
  # nulls from valuesObject. The server ignores it for S3, but the
  # operator compares its spec.config with the running file and holds a
  # changed `storage.path` back as RestartForbidden. So both sides carry
  # the chart's default, spelled out.
  path: /var/cache/batlehub
  {{- end }}
{{- if $b.valkey.enabled }}
cache:
  type: redis
  url: "${CACHE_URL}"
{{- end }}
auth:
  {{- if $b.oidc.enabled }}
  - type: oidc
    name: {{ $b.oidc.name }}
    issuer_url: "${OIDC_ISSUER_URL}"
    client_id: "${OIDC_CLIENT_ID}"
    client_secret: "${OIDC_CLIENT_SECRET}"
    # The path is FIXED -- /api/v1/auth/oidc/callback is one route
    # whatever the provider is called, and the provider a code is
    # redeemed at comes from the login state the server kept, not
    # from the URL. Building it from `name` would look tidier and
    # break the day that name changed.
    redirect_uri: "https://{{ $b.dns }}/api/v1/auth/oidc/callback"
    scopes:
      {{- toYaml $b.oidc.scopes | nindent 6 }}
    user_id_claim: {{ $b.oidc.userIdClaim }}
    role_claim: {{ $b.oidc.roleClaim }}
    role_mappings:
      {{- toYaml $b.oidc.roleMappings | nindent 6 }}
  {{- end }}
  {{- if $b.kubeAuth.enabled }}
  - type: kubernetes
    # api_server, ca_cert_path and token_path are left at their
    # in-cluster defaults -- the env vars and the projected files the
    # kubelet already puts in the pod.
    audiences:
      - {{ $b.kubeAuth.audience }}
    role_mappings:
      {{- toYaml $b.kubeAuth.roleMappings | nindent 6 }}
  {{- end }}
  {{- if $root.Values.operator.enabled }}
  # weebo-batlehub's admin token, as its argon2id hash: the bearer
  # itself stays in the operator's Secret (secret/operator-token.yaml).
  # The hash arrives through the environment, read at startup: a
  # rotated token (tofu -replace) needs a restart of the pod, nothing
  # here changes to roll it.
  - type: token
    tokens:
      - value: "${OPERATOR_TOKEN_HASH}"
        role: admin
        user_id: weebo-batlehub-operator
  {{- end }}
{{- end }}
