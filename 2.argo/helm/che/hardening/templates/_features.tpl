{{- /*
  The operator chart switch each feature needs (che.hardening.operator,
  passed in as .Values.operator). Enabling a feature whose switch is off is a
  refused render: the alternative is a WeeboSiConfig the operator cannot act
  on, found later as a Degraded condition.
*/ -}}
{{- define "hardening.checkRbac" -}}
{{- $f := .Values.config.features -}}
{{- $op := .Values.operator | default dict -}}
{{- $need := dict
      "identity"        (((($op.identity).rbac).enabled))
      "kubearmorPolicy" (((($op.kubearmorPolicy).rbac).enabled))
      "registryConfig"  (((($op.registryConfig).rbac).enabled))
      "endpointAuth"    (((($op.endpointAuth).rbac).enabled)) -}}
{{- range $feature, $granted := $need -}}
{{- if and (get $f $feature).enabled (not $granted) -}}
{{- fail (printf "config.features.%s is enabled but che.hardening.operator.%s.rbac.enabled is not (2.argo/helm/che/main/values.yaml)" $feature $feature) -}}
{{- end -}}
{{- end -}}
{{- with $f.networkProfiles -}}
{{- if and .enabled (eq ((.enforcement).backend | default "Auto") "Cilium") (not (((($op.networkProfiles).cilium).enabled))) -}}
{{- fail "config.features.networkProfiles uses the Cilium backend but che.hardening.operator.networkProfiles.cilium.enabled is not (2.argo/helm/che/main/values.yaml)" -}}
{{- end -}}
{{- end -}}
{{- end -}}
