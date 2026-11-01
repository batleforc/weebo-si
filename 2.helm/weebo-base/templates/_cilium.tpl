{{/*
weebo-base.ciliumNetworkPolicies: one CiliumNetworkPolicy per entry of
.Values.ciliumNetworkPolicies.policies, only when
.Values.ciliumNetworkPolicies.enabled is true.

  ciliumNetworkPolicies:
    enabled: false              # chart-wide switch
    policies:
      <name>:                   # map, not list: a main chart can override one
        enabled: true           # optional, default true
        namespace: <ns>         # required, explicit even for the release ns
        endpointSelector: {}    # required, Cilium selector
        allowHost: true         # optional, default true (see below)
        ingress: []             # Cilium ingress rules, rendered as-is
        egress: []              # Cilium egress rules, rendered as-is
        reaches: []             # optional, hostnames reached through Traefik

A rule only makes the endpoint default-deny for the direction it lists, so an
ingress-only policy leaves egress open, like openbao-ingress and
traefik-ingress already do.

allowHost adds `fromEntities: [host, remote-node]`. On this single node the
kubelet probes, the apiserver calling webhooks and the host-network scrapers
(otel-controlplane) all show up as `host`: a policy without it takes the pod's
readiness down with it.

reaches lists the *.weebo.poc names the selected pods open through Traefik
(s3-main, auth...). The policy can only allow "to Traefik:8443"; which backend
that ends on is an application fact, kept on the policy as the
weebo.io/reaches annotation so that `task docs:netflow` draws it.

Every ingress rule must name a source (from*), every egress rule a destination
(to*). Cilium reads a rule with only toPorts as "from anywhere", which is
exactly the mistake a default-deny policy is there to avoid.
A chart can also compute policies from its own configuration (angos derives
its egress FQDNs from its upstreams) and hand them over:

  {{- include "weebo-base.ciliumNetworkPolicies" (dict "ctx" . "extra" $policies) -}}

Values win over `extra`, key by key, so `enabled: false` in values still
turns a computed policy off.
*/}}
{{- define "weebo-base.ciliumNetworkPolicies" -}}
{{- $ctx := hasKey . "ctx" | ternary .ctx . -}}
{{- $cfg := $ctx.Values.ciliumNetworkPolicies | default dict -}}
{{- if $cfg.enabled -}}
{{- $chart := $ctx.Chart.Name -}}
{{- $policies := mergeOverwrite (deepCopy (.extra | default dict)) (deepCopy ($cfg.policies | default dict)) -}}
{{- range $name, $p := $policies -}}
{{- if and $p (ne (toString $p.enabled) "false") -}}
{{- include "weebo-base.validateCiliumPolicy" (dict "chart" $chart "name" $name "policy" $p) -}}
{{- $ingress := $p.ingress | default list -}}
{{- if ne (toString $p.allowHost) "false" -}}
{{- $ingress = prepend $ingress (dict "fromEntities" (list "host" "remote-node")) -}}
{{- end }}
---
apiVersion: cilium.io/v2
kind: CiliumNetworkPolicy
metadata:
  name: {{ $name }}
  namespace: {{ $p.namespace }}
  labels:
    app.kubernetes.io/managed-by: weebo-base
  annotations:
    {{- with $p.reaches }}
    weebo.io/reaches: {{ join "," . | quote }}
    {{- end }}
    argocd.argoproj.io/sync-wave: "1"
    argocd.argoproj.io/sync-options: SkipDryRunOnMissingResource=true
spec:
  endpointSelector:
    {{- toYaml $p.endpointSelector | nindent 4 }}
  {{- with $ingress }}
  ingress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with $p.egress }}
  egress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end -}}
{{- end -}}
{{- end -}}
{{- include "weebo-base.netflowReaches" $ctx -}}
{{- end -}}

{{/*
weebo-base.netflowReaches: the same relation as a policy's `reaches`, for
pods no weebo-base policy selects (a NetworkPolicy shipped by an upstream
chart, a policy switched off...):

  ciliumNetworkPolicies:
    reaches:
      - namespace: weebo-si-hardening
        endpointSelector: {matchLabels: {app.kubernetes.io/name: endpoint-gateway}}
        hosts: [auth.weebo.poc]     # "*" = every name the docs can resolve

Documentation only: rendered as a NetflowReaches document when
`netflowRender` is set, which `task docs:netflow` does and Argo CD never
does, so nothing reaches the cluster.
*/}}
{{- define "weebo-base.netflowReaches" -}}
{{- $entries := (.Values.ciliumNetworkPolicies | default dict).reaches | default list -}}
{{- range $i, $e := $entries -}}
{{- if or (empty $e.namespace) (not (hasKey $e "endpointSelector")) (empty $e.hosts) -}}
{{- fail (printf "%s: ciliumNetworkPolicies.reaches[%d] needs namespace, endpointSelector and hosts" $.Chart.Name $i) -}}
{{- end -}}
{{- end -}}
{{- if and .Values.netflowRender $entries }}
---
apiVersion: netflow.weebo.io/v1
kind: NetflowReaches
metadata:
  name: {{ .Chart.Name }}-reaches
entries:
  {{- toYaml $entries | nindent 2 }}
{{- end -}}
{{- end -}}

{{- define "weebo-base.validateCiliumPolicy" -}}
{{- $where := printf "%s: ciliumNetworkPolicies.policies.%s" .chart .name -}}
{{- $p := .policy -}}
{{- if not (regexMatch "^[a-z0-9]([-a-z0-9]{0,61}[a-z0-9])?$" .name) -}}
{{- fail (printf "%s: the key is the policy name and must be a DNS label" $where) -}}
{{- end -}}
{{- if empty $p.namespace -}}
{{- fail (printf "%s.namespace is required" $where) -}}
{{- end -}}
{{- if not (hasKey $p "endpointSelector") -}}
{{- fail (printf "%s.endpointSelector is required (`{}` selects every pod of the namespace)" $where) -}}
{{- end -}}
{{- if and (empty $p.ingress) (empty $p.egress) (eq (toString $p.allowHost) "false") -}}
{{- fail (printf "%s has no ingress, no egress and allowHost false: it would select pods and change nothing" $where) -}}
{{- end -}}
{{- if and (hasKey $p "reaches") (not (kindIs "slice" $p.reaches)) -}}
{{- fail (printf "%s.reaches must be a list of hostnames" $where) -}}
{{- end -}}
{{- range $i, $rule := $p.ingress | default list -}}
{{- if not (or $rule.fromEndpoints $rule.fromEntities $rule.fromCIDR $rule.fromCIDRSet $rule.fromGroups $rule.fromNodes) -}}
{{- fail (printf "%s.ingress[%d] has no from* selector: Cilium would read it as `from anywhere`" $where $i) -}}
{{- end -}}
{{- end -}}
{{- range $i, $rule := $p.egress | default list -}}
{{- if not (or $rule.toEndpoints $rule.toEntities $rule.toCIDR $rule.toCIDRSet $rule.toFQDNs $rule.toServices $rule.toGroups $rule.toNodes) -}}
{{- fail (printf "%s.egress[%d] has no to* selector: Cilium would read it as `to anywhere`" $where $i) -}}
{{- end -}}
{{- end -}}
{{- end -}}
