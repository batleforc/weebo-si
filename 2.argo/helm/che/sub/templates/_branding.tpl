{{/*
The dashboard branding built by 3.custo/batlehub-theme, copied into
files/branding/ by its `npm run build`.
*/}}

{{/* One hash over every path and content: changes when any file does. */}}
{{- define "che.branding.checksum" -}}
{{- $sum := "" -}}
{{- range $path, $content := .Files.Glob "files/branding/*" -}}
{{- $sum = print $sum $path (toString $content | sha256sum) -}}
{{- end -}}
{{- sha256sum $sum -}}
{{- end -}}
