{{/*
weebo-base.require: fail the render when one of the named values is missing or
empty. Dotted paths reach into maps.

  {{- include "weebo-base.require" (dict "ctx" . "keys" (list "repo" "branch" "project")) -}}

repo/branch/project default to "" in every values.yaml and only come from the
app of apps (2.argo/app). A chart rendered without them produces Applications
pointing at nothing -- Argo CD accepts those and fails much later, so it is
caught here instead.
*/}}
{{- define "weebo-base.require" -}}
{{- $chart := .ctx.Chart.Name -}}
{{- range $key := .keys -}}
{{- $value := $.ctx.Values -}}
{{- range $part := splitList "." $key -}}
{{- $value = (kindIs "map" $value) | ternary (get $value $part) nil -}}
{{- end -}}
{{- if empty $value -}}
{{- fail (printf "%s: .Values.%s is required -- it is set by the app of apps (2.argo/app), render through it or pass --set %s=..." $chart $key $key) -}}
{{- end -}}
{{- end -}}
{{- end -}}
