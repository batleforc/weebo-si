{{/*
`true` while the chart's own Deployment serves the registry: until
`operator.serving` moves the traffic to the operator's instance.
*/}}
{{- define "angos.chartServes" -}}
{{- if not (and .Values.operator.enabled .Values.operator.serving) }}true{{ end -}}
{{- end -}}

{{/*
The Service the IngressRoute and oauth2-proxy send registry traffic to.
*/}}
{{- define "angos.backend" -}}
{{- if include "angos.chartServes" . }}angos{{ else }}{{ .Values.operator.instance.name }}{{ end -}}
{{- end -}}
