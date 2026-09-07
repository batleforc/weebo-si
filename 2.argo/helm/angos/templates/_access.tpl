{{/*
Turns the small vocabulary in `angos.repositories.*.access` and `angos.policy`
into the CEL angos evaluates. One place, so a subject means the same thing in
every rule and a new registry cannot invent its own spelling.

A subject is one of:
  anonymous       no identity at all -- everyone, including a passer-by
  provider:<name> any identity a given `[auth.oidc.<name>]` block validated
  group:<name>    an identity whose `groups` claim carries that group, which
                  only the browser/CLI provider emits
  namespace:<ns>  any workload running in that Kubernetes namespace
  serviceaccount:<ns>:<name>
                  one workload identity exactly

The last two read the `sub` of a projected service-account token, which the
apiserver mints as `system:serviceaccount:<namespace>:<name>`. They pin the
`kube` provider first, both because that claim means nothing elsewhere and
because CEL's `&&` returns false rather than an error when one side is false --
so a browser identity fails the provider test and never reaches the `sub`
index, which would throw for a token that has no `sub`.

The trailing colon in the namespace form is load-bearing: without it `prod`
would also match `production`.

Rendered rules are TOML literal strings (single quotes) so the CEL inside can
use double quotes throughout and nothing has to be escaped. The guard on
`"groups" in ...` is not decoration: indexing a claim that is absent throws,
and a throw ends evaluation as a deny for the whole request.
*/}}

{{- define "angos.access.subject" -}}
{{- if eq . "anonymous" -}}
true
{{- else if hasPrefix "provider:" . -}}
identity.oidc != null && identity.oidc.provider_name == "{{ trimPrefix "provider:" . }}"
{{- else if hasPrefix "group:" . -}}
identity.oidc != null && "groups" in identity.oidc.claims && "{{ trimPrefix "group:" . }}" in identity.oidc.claims["groups"]
{{- else if hasPrefix "serviceaccount:" . -}}
{{- $sa := splitList ":" (trimPrefix "serviceaccount:" .) -}}
{{- if ne (len $sa) 2 -}}
{{- fail (printf "angos: %q -- the service account form is serviceaccount:<namespace>:<name>" .) -}}
{{- end -}}
identity.oidc != null && identity.oidc.provider_name == "kube" && identity.oidc.claims["sub"] == "system:serviceaccount:{{ index $sa 0 }}:{{ index $sa 1 }}"
{{- else if hasPrefix "namespace:" . -}}
identity.oidc != null && identity.oidc.provider_name == "kube" && identity.oidc.claims["sub"].startsWith("system:serviceaccount:{{ trimPrefix "namespace:" . }}:")
{{- else -}}
{{- fail (printf "angos: unknown access subject %q -- expected anonymous, provider:<name>, group:<name>, namespace:<ns> or serviceaccount:<ns>:<name>" .) -}}
{{- end -}}
{{- end -}}

{{/*
One rule: the subjects OR'd together, gated on the actions of one verb.
Takes a dict of `subjects` (list) and `actions` (list).
*/}}
{{- define "angos.access.rule" -}}
{{- $conds := list -}}
{{- range .subjects -}}
{{- $conds = append $conds (printf "(%s)" (include "angos.access.subject" .)) -}}
{{- end -}}
{{- $who := first $conds -}}
{{- if gt (len $conds) 1 -}}
{{- $who = printf "(%s)" (join " || " $conds) -}}
{{- end -}}
{{- $quoted := list -}}
{{- range .actions -}}
{{- $quoted = append $quoted (printf "%q" .) -}}
{{- end -}}
{{ $who }} && request.action in [{{ join ", " $quoted }}]
{{- end -}}

{{/*
The verbs a repository grants, and the actions each one covers. Only actions
that carry a namespace belong here: everything else (the catalog, the job
queue, the API version, the token endpoint) never reaches a repository policy
and is decided by the global one.
*/}}
{{- define "angos.access.verbs" -}}
pull: ["get-manifest", "get-blob", "get-referrers", "list-tags"]
browse: ["list-revisions", "list-uploads"]
push: ["start-upload", "update-upload", "complete-upload", "cancel-upload", "get-upload", "mount-blob", "put-manifest"]
delete: ["delete-manifest", "delete-blob"]
{{- end -}}
