{{/*
Turns the small vocabulary in `angos.repositories.*.access` and `angos.policy`
into the CEL angos evaluates. One place, so a subject means the same thing in
every rule and a new registry cannot invent its own spelling.

A subject is one of:
  anonymous       no identity at all -- everyone, including a passer-by
  provider:<name> any identity a given `[auth.oidc.<name>]` block validated
  group:<name>    an identity whose `groups` claim carries that group, which
                  only the browser/CLI provider emits

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
{{- else -}}
{{- fail (printf "angos: unknown access subject %q -- expected anonymous, provider:<name> or group:<name>" .) -}}
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
