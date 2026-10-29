{{/*
The files built by 3.custo/batlehub-theme, copied into files/theme/ by its
`npm run build`.
*/}}
{{- define "authentik.theme.files" -}}
{{- range $path, $_ := .Files.Glob "files/theme/**" }}
{{ $path }}
{{- end }}
{{- end -}}

{{/* ConfigMap key for a file: its path under files/theme/, `/` -> `_`. */}}
{{- define "authentik.theme.key" -}}
{{- trimPrefix "files/theme/" . | replace "/" "_" -}}
{{- end -}}
