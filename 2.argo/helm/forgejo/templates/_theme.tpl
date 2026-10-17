{{/*
The theme built by 3.custo/forgejo, copied into files/theme/ by its
`npm run build`. Everything but theme.yaml is a file Forgejo serves or renders
from its custom directory, at the same relative path.
*/}}
{{- define "forgejo.theme.files" -}}
{{- range $path, $_ := .Files.Glob "files/theme/{public,templates}/**" }}
{{ $path }}
{{- end }}
{{- end -}}

{{/* ConfigMap key for a file: its path under files/theme/, `/` -> `_`. */}}
{{- define "forgejo.theme.key" -}}
{{- trimPrefix "files/theme/" . | replace "/" "_" -}}
{{- end -}}

{{/* [ui] settings written by the build next to the files. */}}
{{- define "forgejo.theme.settings" -}}
{{- .Files.Get "files/theme/theme.yaml" -}}
{{- end -}}

{{/* One hash over every path and content: changes when any file does. */}}
{{- define "forgejo.theme.checksum" -}}
{{- $sum := "" -}}
{{- range $path, $content := .Files.Glob "files/theme/**" -}}
{{- $sum = print $sum $path (toString $content | sha256sum) -}}
{{- end -}}
{{- sha256sum $sum -}}
{{- end -}}
